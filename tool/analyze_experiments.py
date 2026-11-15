import json
import time
import numpy as np
from scipy.optimize import linprog
from scipy.stats import friedmanchisquare, wilcoxon

with open("build/experiment_results.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print("=== SKENARIO S1-S9 ===")
for code, sc in data["scenarios"].items():
    if not sc["feasible"]:
        print(f"{code}: INFEASIBLE (B={sc['budget']}, minTotal={sc['minTotal']}, shortfall={sc['shortfall']})")
        continue

    cats = sc["categories"]
    B = sc["budget"]
    active_cats = [c for c in cats if c["active"]]
    total_w = sum(c["weight"] for c in active_cats)

    c_obj = []
    bounds = []
    fixed_w = 0.0
    const_offset = 0.0
    A_ub_row = []

    for cat in active_cats:
        w = cat["weight"]
        m = cat["min"]
        r = cat["target"]
        if r > m:
            coef = -(w / (total_w * (r - m)))
            c_obj.append(coef)
            bounds.append((m, r))
            const_offset += -(w * m) / (total_w * (r - m))
            A_ub_row.append(1.0)
        else:
            fixed_w += w / total_w
            c_obj.append(0.0)
            bounds.append((m, m))
            A_ub_row.append(1.0)

    scale = 1e6
    c_scaled = [c * scale for c in c_obj]
    times = []
    lp_val = None
    for _ in range(30):
        t0 = time.perf_counter()
        res = linprog(c=c_scaled, A_ub=[A_ub_row], b_ub=[B], bounds=bounds, method="highs")
        t1 = time.perf_counter()
        times.append((t1 - t0) * 1000.0)
        lp_val = -(res.fun / scale) + const_offset + fixed_w

    gap = ((lp_val - sc["meanF"]) / lp_val * 100.0) if lp_val > 0 else 0.0
    b0 = sc["baseline"]
    s1 = sc["seed1"]
    alloc_str = [f"{a['name']}={a['amount']//1000}rb" for a in s1["allocations"]]
    print(
        f"{code:4s} | B={B:7d} | F_best={sc['bestF']:.6f} | F_mean={sc['meanF']:.6f}+/-{sc['sdF']:.6f} "
        f"| GenConv={sc['meanGen']:5.2f} | Layak={sc['feasiblePct']:5.1f}% | F0={b0['F0']:.6f} "
        f"| F_LP={lp_val:.6f} | Gap={gap:.4f}% | t_GA={sc['meanTimeMs']:.2f}ms | t_LP={np.mean(times):.2f}ms "
        f"| High: {b0['highAchieved']}/{b0['highTotal']} vs {s1['highAchieved']}/{s1['highTotal']} "
        f"| SisaGA={s1['unallocated']} | Seed1={alloc_str}"
    )

print("\n=== UJI PARAMETER (C0-C8 + BestCombo) ===")
params = data["parameters"]
for cfg_name, per_sc in params.items():
    parts = []
    for sc_code in ["S2", "S3", "S8"]:
        s = per_sc[sc_code]
        parts.append(f"{sc_code}: F={s['meanF']:.6f}+/-{s['sdF']:.6f}, g={s['meanGen']:.2f}, t={s['meanTimeMs']:.2f}ms")
    print(f"{cfg_name:10s} | " + " | ".join(parts))

print("\n=== UJI FRIEDMAN & WILCOXON-HOLM (Generasi Konvergensi & Fitness) ===")
groups = {
    "N (C1=30, C0=50, C2=100)": ["C1", "C0", "C2"],
    "Gmax (C3=50, C4=100, C0=200)": ["C3", "C4", "C0"],
    "Pc (C5=0.60, C0=0.80, C6=0.90)": ["C5", "C0", "C6"],
    "Pm (C7=0.01, C0=0.05, C8=0.10)": ["C7", "C0", "C8"],
}

for sc_code in ["S2", "S3", "S8"]:
    print(f"\n--- Scenario {sc_code} ---")
    for gname, cfgs in groups.items():
        f_arrays = [params[c][sc_code]["fitnessPerSeed"] for c in cfgs]
        g_arrays = [params[c][sc_code]["genPerSeed"] for c in cfgs]
        if all(np.allclose(f_arrays[0], arr) for arr in f_arrays[1:]):
            f_p = 1.0
        else:
            _, f_p = friedmanchisquare(*f_arrays)
        if all(np.allclose(g_arrays[0], arr) for arr in g_arrays[1:]):
            g_p = 1.0
        else:
            _, g_p = friedmanchisquare(*g_arrays)
        print(f"  {gname:32s} -> Fitness p={f_p:.4g} | GenConv p={g_p:.4g}")
        if g_p < 0.05:
            pairs = [(0, 1), (0, 2), (1, 2)]
            raw_p = []
            for i, j in pairs:
                diff = np.array(g_arrays[i]) - np.array(g_arrays[j])
                if np.all(diff == 0):
                    raw_p.append(1.0)
                else:
                    _, pv = wilcoxon(g_arrays[i], g_arrays[j])
                    raw_p.append(pv)
            order = np.argsort(raw_p)
            holm = [0.0] * len(raw_p)
            prev = 0.0
            for rank, idx in enumerate(order):
                adj = min(1.0, raw_p[idx] * (len(raw_p) - rank))
                prev = max(prev, adj)
                holm[idx] = prev
            for (i, j), hp in zip(pairs, holm):
                print(f"     Wilcoxon-Holm {cfgs[i]} vs {cfgs[j]}: p_holm={hp:.4g}")

    g_c0 = params["C0"][sc_code]["genPerSeed"]
    g_bc = params["BestCombo"][sc_code]["genPerSeed"]
    t_c0 = params["C0"][sc_code]["timePerSeed"]
    t_bc = params["BestCombo"][sc_code]["timePerSeed"]
    _, p_g = wilcoxon(g_c0, g_bc) if not np.all(np.array(g_c0) == np.array(g_bc)) else (0, 1.0)
    _, p_t = wilcoxon(t_c0, t_bc) if not np.all(np.array(t_c0) == np.array(t_bc)) else (0, 1.0)
    print(f"  BestCombo vs C0: gen {np.mean(g_c0):.2f} -> {np.mean(g_bc):.2f} (p={p_g:.4g}), time {np.mean(t_c0):.2f}ms -> {np.mean(t_bc):.2f}ms (p={p_t:.4g})")
