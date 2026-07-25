# MATLAB 项目 — CLAUDE.md

MATLAB 科研代码仓。格式规范、命名规则、文件夹结构、文档格式等由 `scientific-research` skill 统一管理。项目工作流（三文件、阶段路由、输出归属）同样由该 skill 控制，各项目 CLAUDE.md 仅记录项目特定映射。

## 活跃项目

- `Project/Postgraduate/Project_01_distributed_fault_monitoring/` — Plant-Wide Monitoring and Fault Localization（参见项目内 CLAUDE.md）
- 旧项目归档于 `.Old/`

## MATLAB 通用操作规则

### 路径添加

调用 `Common/` 或项目 `Function/`、`Script/` 下的代码前，在脚本开头：

```matlab
addpath(genpath('../../../../Common/'));   % 从 Project/Postgraduate/Project_XX/Script/ 到仓库根
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));
```

`genpath` 递归包含所有子目录。`Common/` 的 `../` 层数 = 从当前脚本目录到仓库根的深度，初始化时现场计算，不要照搬其他项目。

### 标准化绘图 — Run_visualization

所有绘图完成后调用 `Run_visualization` 统一格式：

- **循环出图**：`figh = figure; plot(...); Run_visualization(figh);`
- **单图**：省略句柄，默认 `gcf`
- 位于 `Common/Visualization/Run_visualization.m`，调用链：`fig_setting` → `axes_setting_2d` → `label_setting_2d` → 统一线宽 1.5
