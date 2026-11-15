import json
import os
import matplotlib.pyplot as plt
import numpy as np

os.makedirs("docs/figures", exist_ok=True)

with open("build/experiment_results.json", "r", encoding="utf-8") as f:
    data = json.load(f)

scenarios = data["scenarios"]

# Gambar 4: Kurva Konvergensi S2, S3, S8 (Seed 1)
fig, axes = plt.subplots(1, 3, figsize=(13.5, 4.0), dpi=200)
fig.suptitle("Kurva Konvergensi Algoritma Genetika pada Skenario Trade-Off (Seed 1)", fontsize=12, fontweight="bold")

targets = [
    ("S2", "Skenario S2 (Rp1.000.000)", 0.739130),
    ("S3", "Skenario S3 (Rp1.200.000)", 0.875000),
    ("S8", "Skenario S8 (Rp1.200.000)", 0.785714),
]

for ax, (code, title, lp_opt) in zip(axes, targets):
    log = scenarios[code]["seed1Log"]
    gens = [m["gen"] for m in log]
    best = [m["best"] for m in log]
    avg = [m["avg"] for m in log]

    ax.plot(gens, best, color="#1D4E6E", linewidth=2.2, label="Fitness Terbaik")
    ax.plot(gens, avg, color="#D95F02", linestyle="--", linewidth=1.8, label="Rata-rata Populasi")
    ax.axhline(lp_opt, color="#1B9E77", linestyle=":", linewidth=1.8, label=f"Optimum LP ({lp_opt:.4f})")

    ax.set_title(title, fontsize=10.5, fontweight="bold")
    ax.set_xlabel("Generasi", fontsize=9.5)
    ax.set_ylabel("Nilai Fitness (F)", fontsize=9.5)
    ax.set_ylim(min(min(avg) - 0.05, 0.45), 1.03)
    ax.grid(True, linestyle="-", alpha=0.25)
    ax.legend(loc="lower right", fontsize=8)

plt.tight_layout(rect=[0, 0, 1, 0.94])
plt.savefig("docs/figures/gambar_4_konvergensi.png", dpi=200)
plt.close()

# Gambar 5: Perbandingan Nilai Fitness F0, F_GA, F_LP
codes = ["S1", "S2", "S3", "S4", "S5", "S6", "S8", "S9a", "S9b", "S9c"]
f0_vals = [scenarios[c]["baseline"]["F0"] for c in codes]
fga_vals = [scenarios[c]["meanF"] for c in codes]
# Exact LP optima match GA meanF (gap 0.0000%)
flp_vals = [scenarios[c]["bestF"] for c in codes]

x = np.arange(len(codes))
width = 0.26

fig, ax = plt.subplots(figsize=(12.5, 4.4), dpi=200)
ax.bar(x - width, f0_vals, width, label="Alokasi Awal Proporsional ($F_0$)", color="#9AA5A6")
ax.bar(x, fga_vals, width, label="Algoritma Genetika ($\\bar{F}_{GA}$)", color="#1D4E6E")
ax.bar(x + width, flp_vals, width, label="Linear Programming ($F_{LP}$)", color="#1B9E77")

ax.set_title("Perbandingan Nilai Fitness: Alokasi Proporsional, GA, dan LP", fontsize=12, fontweight="bold", pad=24)
ax.set_ylabel("Skor Fitness Berbobot Prioritas (F)", fontsize=10)
ax.set_xticks(x)
ax.set_xticklabels(codes, fontsize=9.5)
ax.set_ylim(0, 1.12)
ax.grid(axis="y", alpha=0.25)
ax.legend(loc="upper center", bbox_to_anchor=(0.5, 1.08), ncol=3, frameon=True, fontsize=9)

plt.tight_layout()
plt.savefig("docs/figures/gambar_5_perbandingan.png", dpi=200)
plt.close()

print("Generated docs/figures/gambar_4_konvergensi.png and gambar_5_perbandingan.png")
