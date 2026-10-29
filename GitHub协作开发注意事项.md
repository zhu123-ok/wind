# GitHub 协作开发注意事项

本文档用于本项目四名成员共同维护 MATLAB 代码、实验数据、图表和报告。核心原则是：**`main` 分支始终保存可以正常运行的版本，个人开发在独立分支中完成，检查无误后再合并。**

项目地址：[https://github.com/zhu123-ok/wind](https://github.com/zhu123-ok/wind)

---

## 1. 第一次下载项目

第一次参与项目时，在合适的本地目录运行：

```bash
git clone https://github.com/zhu123-ok/wind.git
cd wind
```

检查远程仓库和当前分支：

```bash
git remote -v
git branch --show-current
```

正常情况下，远程仓库名称为 `origin`，当前分支为 `main`。

不要重复下载多个压缩包并手工复制代码，否则很难判断哪个版本最新，也容易遗漏文件。

---

## 2. 四部分代码负责人

| 成员 | 主要工作 | 主要代码 |
|---|---|---|
| 成员 1 | 风电场模型、数据、目标函数 | `windflo_model.m`、`windflo_expected_power.m`、`windflo_evaluate.m` |
| 成员 2 | 解码、约束、修复器、缓存和评价接口 | `windflo_decode_continuous.m`、`windflo_repair_layout.m`、`windflo_evaluate_population.m` |
| 成员 3 | CCGDE3、NSGA-II 和多目标选择 | `CCGDE3.m`、`NSGA2.m`、`run_algorithm.m`、多目标工具函数 |
| 成员 4 | 实验、性能指标、图表和结果分析 | `run_experiments_continuous.m`、`mo_metrics.m`、绘图代码和分析文档 |

负责人不是文件的唯一修改者。其他成员需要修改对应模块时，应先在小组中说明，并在 Pull Request 中标记负责人检查。

公共接口文件（例如 `run_algorithm.m`、`windflo_evaluate_population.m` 和实验主程序）会影响多个模块，修改前必须说明输入、输出和修改原因。

---

## 3. 分支使用规则

### 3.1 不直接在 `main` 上开发

每次开始新任务前，先切换并更新 `main`：

```bash
git switch main
git pull origin main
```

然后创建自己的功能分支：

```bash
git switch -c feature/repair-mask
```

推荐的分支命名如下：

| 类型 | 命名格式 | 示例 |
|---|---|---|
| 新功能 | `feature/功能名称` | `feature/fatigue-objective` |
| 修复问题 | `fix/问题名称` | `fix/cache-repair-info` |
| 实验 | `experiment/实验名称` | `experiment/200-turbines` |
| 文档 | `docs/文档名称` | `docs/result-analysis` |

分支名称尽量使用简短英文、小写字母和连字符，不要使用“新建文件夹”“最终版”“最终版2”等名称。

### 3.2 一个分支只完成一件主要工作

例如，修复缓存问题和新增机械疲劳目标应放在两个不同分支中。这样出现问题时容易检查和撤回，也方便不同成员分别审核。

---

## 4. 每次提交代码的流程

修改前先确认自己所在的分支：

```bash
git status
git branch --show-current
```

完成一个小阶段后查看改动：

```bash
git status
git diff
```

只添加本次任务相关文件：

```bash
git add WindFLO-master/MATLAB/project/CCGDE3.m
git add WindFLO-master/MATLAB/project/run_algorithm.m
```

不建议不了解改动内容时直接使用 `git add .`，因为可能把临时数据、个人配置或无关修改一起提交。

提交示例：

```bash
git commit -m "feat: add movable mask to layout repair"
git push -u origin feature/repair-mask
```

常用提交类型：

| 类型 | 用途 | 示例 |
|---|---|---|
| `feat` | 新增功能 | `feat: add continuous CCGDE3 grouping` |
| `fix` | 修复错误 | `fix: keep current repair information on cache hit` |
| `test` | 增加或修改测试 | `test: add evaluator consistency check` |
| `docs` | 修改文档 | `docs: explain experiment indicators` |
| `refactor` | 调整代码但不改变功能 | `refactor: simplify objective evaluation` |
| `plot` | 修改绘图或可视化 | `plot: add Pareto projection figure` |

提交说明应写清“做了什么”，不要只写 `update`、`修改`、`最终版`。

---

## 5. Pull Request 和合并规则

代码推送后，在 GitHub 上从个人分支向 `main` 创建 Pull Request（PR）。PR 中至少写明：

1. 本次修改解决了什么问题；
2. 修改了哪些重要文件；
3. 输入、输出或公共接口是否变化；
4. 使用了什么参数进行测试；
5. 测试是否通过，结果文件保存在哪里；
6. 是否会影响其他成员正在进行的实验。

建议至少由一名相关模块成员检查后再合并。以下修改最好由两人共同确认：

- 目标函数的定义、符号或单位发生变化；
- 约束、修复方法或候选点选择方法发生变化；
- CCGDE3 或 NSGA-II 的核心步骤发生变化；
- 公共输入输出接口发生变化；
- 实验预算、种群规模、随机种子或指标计算方式发生变化；
- 正式实验结果被替换。

合并完成后，个人本地更新 `main`：

```bash
git switch main
git pull origin main
```

确认功能分支已经合并且不再需要后，可以删除本地分支：

```bash
git branch -d feature/repair-mask
```

---

## 6. MATLAB 代码协作规范

### 6.1 公共函数必须说明输入输出

每个主要函数开头保留简短注释，至少说明函数用途、输入和输出。例如：

```matlab
function result = run_algorithm(name, problem, options)
%RUN_ALGORITHM 使用统一接口调用多目标优化算法
% name: 算法名称，例如 'CCGDE3' 或 'NSGA2'
% problem: 问题模型和评价函数
% options: 种群规模、评价次数等算法参数
% result: 非支配解、目标值和运行历史
```

代码风格保持简单，变量名称能够表示含义；关键算法步骤写必要注释，但不需要给每一行都加注释。

### 6.2 不随意改变公共结构体字段

当前算法通过统一接口调用。若需要增加或删除以下结构体中的字段，应同时检查所有调用位置：

- `problem`
- `options`
- `result`
- `history`
- `details`

修改公共字段时，应在 PR 中列出“修改前”和“修改后”的格式，避免其他人的算法或绘图程序突然不能运行。

### 6.3 保持算法比较公平

对比 CCGDE3 和 NSGA-II 时，应尽量使用相同的：

- 问题模型和约束；
- 初始随机种子；
- 种群规模；
- 最大函数评价次数（FE）；
- 目标归一化方法；
- HV 参考点和参考前沿；
- 计算环境和计时方式。

不能为了让某一种算法结果更好，单独改变评价预算或目标函数。

### 6.4 修改后至少完成基本检查

提交算法或评价代码前，至少检查：

1. MATLAB 程序能够正常运行，没有语法错误；
2. 两种算法仍可以通过 `run_algorithm.m` 调用；
3. 解码后风机坐标没有越界；
4. 最小间距和障碍物约束检查结果合理；
5. 三个目标值不是 `NaN` 或 `Inf`；
6. 固定随机种子时结果能够基本复现；
7. 小规模测试通过后再运行正式大规模实验。

---

## 7. 实验数据和图表管理

### 7.1 不要覆盖他人的正式实验

实验结果建议按算法、日期或实验编号保存。例如：

```text
results/
  continuous_100T_20261029/
    config.json
    summary.csv
    run01.mat
```

正式结果必须同时保存实验配置，至少包括：

- Git 提交编号；
- 算法名称；
- 随机种子；
- 风机数量和变量维数；
- 种群规模和最大 FE；
- 运行次数；
- 目标函数版本；
- MATLAB 版本和计算机主要配置。

可使用下面的命令记录当前提交编号：

```bash
git rev-parse HEAD
```

### 7.2 区分源数据和临时文件

应上传：

- MATLAB 源代码；
- 必要的场景和参数文件；
- 汇总后的 CSV、JSON 或较小的结果文件；
- 最终报告使用的图表；
- 实验说明和结果分析文档。

通常不上传：

- MATLAB 自动保存文件和编辑器临时文件；
- 可以重新生成的缓存；
- 大体积中间变量；
- 重复的图片预览；
- 个人电脑路径和本地配置；
- 密码、令牌和其他敏感信息。

提交前检查 `.gitignore` 是否已经排除临时文件。单个文件较大时，先在组内说明；GitHub 普通仓库不适合直接保存大量 `.mat` 实验文件。

### 7.3 图表必须能够追溯

每张正式图最好能够找到对应的绘图脚本和输入数据。图表名称要能反映内容，例如：

```text
pareto_ccgde3_vs_nsga2.png
hv_convergence_100t.png
layout_ccgde3_compromise.png
```

不要只上传一张无法确定来源的“结果图1.png”。

---

## 8. 如何减少代码冲突

1. 开始工作前先在小组中说明准备修改哪些文件；
2. 每天开始开发前先更新 `main`；
3. 一个分支不要积累几天的大量无关修改；
4. 不要同时大范围格式化所有 MATLAB 文件；
5. 公共接口先讨论，再修改实现；
6. 报告尽量按章节分文件编写，最后由负责人合并；
7. 发现其他成员正在修改同一文件时，先协调修改区域。

在功能分支上同步最新 `main` 时，可使用：

```bash
git fetch origin
git merge origin/main
```

如果发生冲突：

1. 不要直接删除看不懂的冲突内容；
2. 找到同时修改该文件的成员一起确认；
3. 保留双方需要的逻辑并删除冲突标记；
4. 重新运行相关 MATLAB 测试；
5. 再提交冲突解决结果。

冲突标记通常如下：

```text
<<<<<<< HEAD
当前分支内容
=======
另一分支内容
>>>>>>> origin/main
```

解决后文件中不能继续保留这些标记。

---

## 9. 禁止或需要谨慎的操作

- 不要把账号密码、GitHub Token 或私人信息提交到仓库；
- 不要在没有说明的情况下强制推送 `main`；
- 不要随意删除他人的分支、代码、数据和图表；
- 不要使用不清楚后果的命令强行覆盖本地修改；
- 不要直接修改正式实验结果来得到更好的数值；
- 不要只上传代码而不记录参数和随机种子；
- 不要把绝对路径写死为某一名成员电脑上的路径；
- 不要在算法比较过程中临时改变评价标准。

如果误提交了包含密码或 Token 的文件，仅删除文件并再次提交是不够的，应立即撤销或更新对应凭据，并联系仓库负责人处理提交历史。

---

## 10. 每日协作建议

每名成员当天开始工作时：

```bash
git switch main
git pull origin main
git switch 自己的功能分支
git merge main
```

当天结束工作前：

```bash
git status
git diff
git add 需要提交的文件
git commit -m "类型: 本次完成的内容"
git push
```

在小组中简要说明：

- 今天完成了什么；
- 分支或 PR 链接；
- 修改了哪些公共接口；
- 测试结果如何；
- 是否需要其他成员配合。

---

## 11. PR 合并前检查清单

- [ ] 当前修改位于个人功能分支，不是直接在 `main` 上完成；
- [ ] 只包含本次任务相关文件；
- [ ] 没有临时文件、账号信息和个人绝对路径；
- [ ] 主要函数已经写明用途、输入和输出；
- [ ] MATLAB 小规模测试可以运行；
- [ ] CCGDE3 和 NSGA-II 的统一调用接口没有被破坏；
- [ ] 算法参数、随机种子和实验预算已经记录；
- [ ] 新图表能够找到对应数据和绘图脚本；
- [ ] 公共接口变化已经在 PR 中说明；
- [ ] 已经处理与最新 `main` 的冲突；
- [ ] 至少一名相关成员完成检查。

遵守以上规则的目的不是增加操作步骤，而是让四个人的模型、算法、实验和报告能够稳定组合，并保证最终结果可以复现和解释。
