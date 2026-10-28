"""绘制连续布局修复器的诊断图。"""

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
from 工具.plot_utils import setup_style, save_fig, PALETTE, PALETTE_LIGHT, COLORS


ROOT = Path(__file__).resolve().parents[1]


def main():
    setup_style('colorblind')
    import matplotlib.pyplot as plt

    path = ROOT / 'WindFLO-master' / 'MATLAB' / 'project' / 'results_continuous' / 'repair_summary.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    algorithms = ('CCGDE3', 'NSGA2')
    items = {name: [x for x in data['items'] if x['algorithm'] == name] for name in algorithms}
    fig, axes = plt.subplots(1, 2, figsize=(8.8, 4.3))

    rates = [100 * np.mean([x['fallbackCount'] > 0 for x in items[name]]) for name in algorithms]
    bars = axes[0].bar(algorithms, rates, width=0.58,
                       color=[PALETTE_LIGHT[0], PALETTE_LIGHT[1]],
                       edgecolor=[PALETTE[0], PALETTE[1]], linewidth=1.4)
    for bar, value in zip(bars, rates):
        axes[0].text(bar.get_x() + bar.get_width() / 2, value,
                     f'{value:.1f}%', ha='center', va='bottom', fontsize=9)
    axes[0].set_ylabel('使用网格兜底的档案解（%）')
    axes[0].text(0.02, 0.95, '(a)', transform=axes[0].transAxes,
                 ha='left', va='top', fontsize=10)

    positions = [0, 1]
    movements = [np.asarray([x['totalMovement'] for x in items[name]], dtype=float) for name in algorithms]
    parts = axes[1].violinplot(movements, positions=positions, widths=0.72,
                              showmeans=False, showmedians=True, showextrema=False)
    for i, body in enumerate(parts['bodies']):
        body.set_facecolor(PALETTE_LIGHT[i])
        body.set_edgecolor(PALETTE[i])
        body.set_alpha(0.85)
    parts['cmedians'].set_color(COLORS['text'])
    parts['cmedians'].set_linewidth(1.4)
    rng = np.random.default_rng(7)
    for i, values in enumerate(movements):
        count = min(80, len(values))
        ids = np.linspace(0, len(values) - 1, count, dtype=int)
        axes[1].scatter(i + rng.uniform(-0.12, 0.12, count), values[ids],
                        s=9, alpha=0.25, color=PALETTE[i], edgecolors='none')
    axes[1].set_xticks(positions, algorithms)
    axes[1].set_ylabel('修复总移动距离（m）')
    axes[1].text(0.02, 0.95, '(b)', transform=axes[1].transAxes,
                 ha='left', va='top', fontsize=10)

    for ax in axes:
        ax.grid(axis='y', alpha=0.14, linestyle='--', color=COLORS['grid'])
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
    fig.savefig(ROOT / '图表' / 'fig_continuous_repair_diagnostics.png', dpi=350, bbox_inches='tight')
    save_fig(fig, str(ROOT / '图表' / 'fig_continuous_repair_diagnostics.pdf'))


if __name__ == '__main__':
    main()
