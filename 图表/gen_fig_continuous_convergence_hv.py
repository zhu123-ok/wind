"""绘制连续变量版 HV 收敛曲线。"""

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


def main():
    setup_style('colorblind')
    import matplotlib.pyplot as plt

    data = json.loads((ROOT / '图表' / 'continuous_analysis_data.json').read_text(encoding='utf-8'))
    fig, ax = plt.subplots(figsize=(7.5, 4.7))
    styles = {'CCGDE3': ('-', 'o'), 'NSGA2': ('--', '^')}
    for i, algorithm in enumerate(('CCGDE3', 'NSGA2')):
        runs = [r for r in data['runs'] if r['algorithm'] == algorithm]
        common_fe = np.asarray(runs[0]['convergenceFE'], dtype=float)
        curves = np.asarray([np.interp(common_fe, r['convergenceFE'], r['convergenceHV']) for r in runs])
        mean = curves.mean(axis=0)
        std = curves.std(axis=0, ddof=1)
        linestyle, marker = styles[algorithm]
        markevery = max(1, len(common_fe) // 8)
        ax.plot(common_fe, mean, color=PALETTE[i], linestyle=linestyle,
                marker=marker, markevery=markevery, markersize=4.5,
                linewidth=2.1, label=f'{algorithm}（均值）')
        ax.fill_between(common_fe, mean - std, mean + std,
                        color=PALETTE[i], alpha=0.14, linewidth=0)
        ax.text(common_fe[-1], mean[-1], f'  {mean[-1]:.3f}',
                color=PALETTE[i], va='center', fontsize=9)
    ax.set_xlabel('目标函数评价次数（FE）')
    ax.set_ylabel('超体积 HV（越大越好）')
    ax.set_xlim(0, data['config']['options']['maxFE'] * 1.04)
    ax.grid(axis='y', alpha=0.18, linestyle='--', color=COLORS['grid'])
    ax.legend(loc='best', frameon=True, edgecolor=COLORS['grid'])
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.savefig(ROOT / '图表' / 'fig_continuous_convergence_hv.png', dpi=350, bbox_inches='tight')
    save_fig(fig, str(ROOT / '图表' / 'fig_continuous_convergence_hv.pdf'))


if __name__ == '__main__':
    main()
