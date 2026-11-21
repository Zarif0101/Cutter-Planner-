//! Browser bridge for Marker Planner: runs sparrow (https://github.com/JeroenGar/sparrow, MIT,
//! Jeroen Gardeyn) on one strip-packing instance and returns the best layout as JSON.
//!
//! Plain C ABI (target wasm32-wasip1), driven from JavaScript:
//!   ptr = sp_alloc(n)                      reserve n bytes, write UTF-8 input there
//!   ok  = sp_solve(inst_ptr, inst_len, warm_ptr, warm_len, time_ms, seed)   1 = ok, 0 = error
//!   sp_result_ptr() / sp_result_len()     final solution JSON (or the error text when ok == 0)
//!   sp_free(ptr, n)                        release an input buffer
//! While running, each shorter feasible layout is passed to the imported `env.sp_progress(ptr, len)`.
//! Solution JSON: { strip_width, density, layout: { placed_items: [{ item_id,
//!   transformation: { rotation (deg), translation: [x, y] } }] } }.
//! Single-threaded; the page runs several Web Workers with different seeds.

use jagua_rs::io::import::Importer;
use jagua_rs::probs::spp::entities::SPSolution;
use jagua_rs::probs::spp::io::ext_repr::{ExtSPInstance, ExtSPSolution};
use rand::SeedableRng;
use rand::rngs::Xoshiro256PlusPlus;
use sparrow::EPOCH;
use sparrow::config::DEFAULT_SPARROW_CONFIG;
use sparrow::consts::{DEFAULT_COMPRESS_TIME_RATIO, DEFAULT_EXPLORE_TIME_RATIO};
use sparrow::optimizer::optimize;
use sparrow::util::listener::{ReportType, SolutionListener};
use sparrow::util::terminator::BasicTerminator;
use std::cell::RefCell;
use std::time::Duration;

#[link(wasm_import_module = "env")]
unsafe extern "C" {
    fn sp_progress(ptr: *const u8, len: usize);
}

thread_local! {
    static RESULT: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
}

struct ProgressListener {
    best: f32,
}

impl SolutionListener for ProgressListener {
    fn report(&mut self, report: ReportType, solution: &SPSolution) {
        if !matches!(report, ReportType::ExplFeas | ReportType::CmprFeas) {
            return;
        }
        let w = solution.strip_width();
        if w >= self.best - 1e-4 {
            return;
        }
        self.best = w;
        if let Ok(s) = serde_json::to_string(&jagua_rs::probs::spp::io::export(solution, *EPOCH)) {
            unsafe { sp_progress(s.as_ptr(), s.len()) };
        }
    }
}

fn run(instance_json: &str, warm_json: &str, time_ms: f64, seed: f64) -> anyhow_lite::Result<String> {
    let ext: ExtSPInstance = serde_json::from_str(instance_json)?;
    let mut cfg = DEFAULT_SPARROW_CONFIG;
    let total = Duration::from_millis(time_ms.clamp(200.0, 3_600_000.0) as u64);
    cfg.expl_cfg.time_limit = total.mul_f32(DEFAULT_EXPLORE_TIME_RATIO);
    cfg.cmpr_cfg.time_limit = total.mul_f32(DEFAULT_COMPRESS_TIME_RATIO);
    cfg.expl_cfg.separator_config.n_workers = 1;
    cfg.cmpr_cfg.separator_config.n_workers = 1;

    let importer = Importer::new(cfg.cde_config, cfg.poly_simpl_tolerance, cfg.narrow_concavity_cutoff_ratio);
    let instance = jagua_rs::probs::spp::io::import_instance(&importer, &ext)?;
    let warm = if warm_json.is_empty() {
        None
    } else {
        let ext_sol: ExtSPSolution = serde_json::from_str(warm_json)?;
        Some(jagua_rs::probs::spp::io::import_solution(&instance, &ext_sol)?)
    };
    let rng = Xoshiro256PlusPlus::seed_from_u64(seed.max(0.0) as u64);
    let mut listener = ProgressListener { best: f32::INFINITY };
    let mut terminator = BasicTerminator::new();
    let solution = optimize(instance, rng, &mut listener, &mut terminator, &cfg.expl_cfg, &cfg.cmpr_cfg, warm.as_ref())?;
    Ok(serde_json::to_string(&jagua_rs::probs::spp::io::export(&solution, *EPOCH))?)
}

/// Minimal error type so any error converts with `?` and prints its message.
mod anyhow_lite {
    pub struct Error(pub String);
    impl<E: std::fmt::Display> From<E> for Error {
        fn from(e: E) -> Self {
            Error(e.to_string())
        }
    }
    pub type Result<T> = std::result::Result<T, Error>;
}

unsafe fn read_str<'a>(ptr: *const u8, len: usize) -> &'a str {
    if len == 0 {
        return "";
    }
    std::str::from_utf8(unsafe { std::slice::from_raw_parts(ptr, len) }).unwrap_or("")
}

#[unsafe(no_mangle)]
pub extern "C" fn sp_alloc(len: usize) -> *mut u8 {
    let mut v = Vec::<u8>::with_capacity(len.max(1));
    let p = v.as_mut_ptr();
    std::mem::forget(v);
    p
}

/// # Safety
/// `ptr` and `cap` must come from one `sp_alloc` call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn sp_free(ptr: *mut u8, cap: usize) {
    unsafe { drop(Vec::from_raw_parts(ptr, 0, cap.max(1))) };
}

/// # Safety
/// The pointers must address `len` readable bytes written by the caller.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn sp_solve(inst_ptr: *const u8, inst_len: usize, warm_ptr: *const u8, warm_len: usize, time_ms: f64, seed: f64) -> i32 {
    let (inst, warm) = unsafe { (read_str(inst_ptr, inst_len), read_str(warm_ptr, warm_len)) };
    let (ok, out) = match run(inst, warm, time_ms, seed) {
        Ok(s) => (1, s),
        Err(e) => (0, e.0),
    };
    RESULT.with(|r| *r.borrow_mut() = out.into_bytes());
    ok
}

#[unsafe(no_mangle)]
pub extern "C" fn sp_result_ptr() -> *const u8 {
    RESULT.with(|r| r.borrow().as_ptr())
}

#[unsafe(no_mangle)]
pub extern "C" fn sp_result_len() -> usize {
    RESULT.with(|r| r.borrow().len())
}
