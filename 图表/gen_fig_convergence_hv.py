"""生成 HV 收敛曲线，实线是均值，色带是一倍标准差。"""

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from 工具 import plot_utils as pu  # noqa: E402


def main():
    pu.setup_style("colorblind")
    import matplotlib.pyplot as plt

    data = json.loads((ROOT / "图表" / "analysis_data.json").read_text(encoding="utf-8"))
    fig, ax = plt.subplots(figsize=(7.5, 4.7))
    linestyles = {"CCGDE3": "-", "NSGA2": "--"}

    for i, algorithm in enumerate(("CCGDE3", "NSGA2")):
        runs = [r for r in data["runs"] if r["algorithm"] == algorithm]
        common_fe = np.asarray(runs[0]["convergenceFE"], dtype=float)
        curves = []
        for run in runs:
            curves.append(np.interp(common_fe, run["convergenceFE"], run["convergenceHV"]))
        curves = np.asarray(curves)
        mean = curves.mean(axis=0)
        std = curves.std(axis=0, ddof=1)
        ax.plot(common_fe, mean, color=pu.PALETTE[i], linestyle=linestyles[algorithm],
                linewidth=2.1, label=algorithm)
        ax.fill_between(common_fe, mean - std, mean + std, color=pu.PALETTE[i], alpha=0.16)

    ax.set_xlabel("目标函数评价次数（FE）")
    ax.set_ylabel("超体积 HV（越大越好）")
    ax.set_xlim(0, data["config"]["options"]["maxFE"])
    ax.grid(axis="y", alpha=0.25, linewidth=0.7)
    ax.legend(loc="lower right")
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(ROOT / "图表" / "fig_convergence_hv.pdf", bbox_inches="tight")
    fig.savefig(ROOT / "图表" / "fig_convergence_hv.png", dpi=350, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()

