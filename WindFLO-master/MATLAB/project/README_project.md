# WindFLO 大规模三目标 MATLAB 项目

## 1. 问题定义

程序从 `M` 个候选点中选择恰好 `N` 个风机位置，统一最小化：

```text
F = [-AEP, LCOE, CVaR95]
```

- AEP：年发电量，取负号后转成最小化目标。
- LCOE：全寿命折现成本除以全寿命折现发电量。
- CVaR95：单机尾流相对损失分布中最差 5% 的平均损失。

约束包括场界、障碍物、固定风机数和任意两台风机距离不小于 `8R=308m`。

## 2. 候选点和随机键

`windflo_make_candidates` 根据场区长宽比生成指定数量的均匀网格点。正式配置为1200个点，网格间距小于308m，因此冲突约束会真实参与搜索。

算法中的一个个体是 `1×M` 随机键。`windflo_decode` 将随机键降序排列，按优先级贪心选择候选点；选中点后，利用预计算的稀疏冲突图屏蔽距离不足308m的点，直到选出 `N` 台风机。

## 3. 调用关系

```text
main_large_scale
  └─ run_experiments
       ├─ windflo_model
       ├─ windflo_make_candidates
       ├─ windflo_prepare_problem
       │    ├─ 稀疏冲突图
       │    └─ 无尾流基准功率
       ├─ run_algorithm('CCGDE3')
       │    └─ CCGDE3
       └─ run_algorithm('NSGA2')
            └─ NSGA2

CCGDE3 / NSGA2
  ├─ windflo_decode
  ├─ windflo_evaluate_population
  │    ├─ 布局缓存
  │    └─ windflo_evaluate
  │         ├─ windflo_check_layout
  │         ├─ windflo_expected_power
  │         └─ LCOE与最小生成树电缆长度
  ├─ mo_non_dominated_sort
  ├─ mo_crowding_distance
  ├─ mo_environmental_selection
  └─ mo_update_archive
```

## 4. CCGDE3实现

本实现采用2013年CCGDE3的主要结构：将高维随机键随机分成两个变量子群，每次只进化一个子群，其他变量由当前非支配解提供协同上下文。子群使用 `DE/rand/1/bin` 产生后代；父代支配后代时保留父代，后代支配父代时保留后代，互不支配时两者都进入候选池，再通过非支配排序和拥挤距离恢复种群规模。

变量组可按 `regroupPeriod` 重新随机分组，以降低固定分组遗漏变量相互作用的风险。

参考：L. M. Antonio and C. A. Coello Coello, *Use of cooperative coevolution for solving large scale multiobjective optimization problems*, IEEE CEC, 2013。

## 5. 连续坐标版（新增）

原有的1200维候选点随机键版完整保留。新版本将每台风机的坐标直接写成连续变量：

```text
X = [x1,y1,x2,y2,...,xN,yN] in [0,1]^(2N)
```

对于100台风机，决策维度为200。`windflo_decode_continuous` 先把归一化坐标缩放到实际场区，然后 `windflo_repair_layout` 依次修复场界、障碍物和 `8R=308m` 最小间距。修复为确定性过程，同一个体不会在多次评价时得到不同目标值。

连续版CCGDE3按风机分组，同一台风机的 `x,y` 坐标始终在同一组。默认分10组，每组10台风机、20个连续变量。

连续版调用关系：

```text
main_continuous
  └─ run_experiments_continuous
       ├─ windflo_model
       ├─ windflo_prepare_continuous_problem
       ├─ run_algorithm('CCGDE3' / 'NSGA2')
       │    └─ windflo_evaluate_population
       │         ├─ windflo_decode_continuous
       │         │    └─ windflo_repair_layout
       │         └─ windflo_evaluate
       └─ MAT / CSV / JSON
```

运行方式：

```matlab
cd('E:/comproject/WindFLO-master/MATLAB/project');
test_continuous_project(); % 先做快速回归测试
experiment = main_continuous(); % 正式连续变量实验
```

结果单独写入 `results_continuous/`，不会覆盖离散版的 `results_large_scale/`。

## 6. 对比算法

第二种算法为标准NSGA-II，使用：

- 二元锦标赛选择；
- 模拟二进制交叉（SBX）；
- 多项式变异；
- 非支配排序；
- 拥挤距离环境选择。

CCGDE3和NSGA-II共享完全相同的候选点、解码器、约束、评价器和函数评价预算。

## 7. 运行方式

快速回归测试：

```matlab
cd('E:/comproject/WindFLO-master/MATLAB/project');
test_project();
```

快速查看完整调用链：

```matlab
outputs = main_compare();
```

正式大规模实验：

```matlab
experiment = main_large_scale();
```

默认正式配置为100台风机、1200个候选点、80个个体、每个算法10000次函数评价、5次独立运行。最终论文建议将 `nRuns` 增加到20或30。

## 8. 输出

`main_large_scale` 在 `results_large_scale` 中生成：

```text
experiment.mat   完整MATLAB结果
summary.csv      各算法HV、IGD、Spacing和时间的均值/标准差
summary.json     参考前沿、每次运行的指标、目标值和布局坐标
```

仓库中的 `validation_results` 是两次、每次32个函数评价的端到端冒烟结果，只用于证明结果文件链路可用，不能作为论文性能结论。

每个算法结果包含：

```text
result.archive         Pareto非支配档案
result.representative  离归一化理想点最近的折中展示解
result.history         评价次数、档案规模和理想点变化
result.evaluations     实际使用的函数评价数
result.cacheHits       重复布局缓存命中数
```

多目标问题不存在唯一的“最佳解”。保留 `result.best` 只是为了兼容旧主程序，它与 `result.representative` 相同，不能把它解释成支配全部其他方案的唯一最优解。
