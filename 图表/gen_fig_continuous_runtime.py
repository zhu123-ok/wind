"""绘制连续变量版运行时间和档案规模配对图。"""

import os, sys, shutil
os.makedirs('工具', exist_ok=True)
for src in ['plot_utils.py']:
    for search in ['skills/shared-scripts', '../skills/shared-scripts']:
        p = os.path.join(search, src)
        if os.path.isfile(p):
            shutil.copy2(p, f'工具/{src}')
            break
sys.path.insert(0, '.')

import json
from pathlib import Path
import numpy as np
from 工具.plot_utils import setup_style, save_fig, PALETTE, COLORS


ROOT = Path(__file__).resolve().parents[1]


def paired_panel(ax, ccg, nsga, ylabel, letter):
    for i in range(len(ccg)):
        ax.plot([0, 1], [ccg[i], nsga[i]], color=COLORS['gray'], linewidth=1.0, alpha=0.65)
    ax.scatter(np.zeros(len(ccg)), ccg, s=45, color=PALETTE[0], marker='o', zorder=3)
    ax.scatter(np.ones(len(nsga)), nsga, s=50, color=PALETTE[1], marker='^', zorder=3)
    ax.scatter([0, 1], [np.mean(ccg), np.mean(nsga)], s=125, marker='D', facecolors='white',
               edgecolors=[PALETTE[0], PALETTE[1]], linewidths=2.0, zorder=4)
    ax.set_xticks([0, 1], ['CCGDE3', 'NSGA2'])
    ax.set_ylabel(ylabel)
    ax.text(0.02, 0.05, f'({letter})', transform=ax.transAxes, fontsize=10)
    ax.grid(axis='y', alpha=0.16, linestyle='--', color=COLORS['grid'])
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)


def main():
    setup_style('colorblind')
    import matplotlib.pyplot as plt

    data = json.loads((ROOT / '图表' / 'continuous_analysis_data.json').read_text(encoding='utf-8'))
    ccg = [r for r in data['runs'] if r['algorithm'] == 'CCGDE3']
    nsga = [r for r in data['runs'] if r['algorithm'] == 'NSGA2']
    fig, axes = plt.subplots(1, 2, figsize=(8.5, 4.15))
    paired_panel(axes[0], np.asarray([r['timeSeconds'] for r in ccg]),
                 np.asarray([r['timeSeconds'] for r in nsga]), '运行时间（s）', 'a')
    paired_panel(axes[1], np.asarray([r['archiveSize'] for r in ccg]),
                 np.asarray([r['archiveSize'] for r in nsga]), '最终档案解数', 'b')
    effect = data['metrics']['timeSeconds']['NSGA2_relative_improvement_percent']
    text = f"NSGA2 {'节省' if effect >= 0 else '增加'} {abs(effect):.1f}%"
    axes[0].text(0.5, 0.98, text, transform=axes[0].transAxes,
                 ha='center', va='top', fontsize=9)
    fig.savefig(ROOT / '图表' / 'fig_continuous_runtime.png', dpi=350, bbox_inches='tight')
    save_fig(fig, str(ROOT / '图表' / 'fig_continuous_runtime.pdf'))


if __name__ == '__main__':
    main()
