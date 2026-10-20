# Matlab

软件项目目录，按“练习项目 / 共享依赖库”分开，代码放各自 `src/`：

```text
Matlab/                       # 一个软件项目根，一个 git 仓库
  projects/
    ml_2_1/                  # 简单练习：一个文件夹，平铺
      case_2_1.m ...
  matlab-project-utils/      # 正式共享依赖库
    src/
      calculations/
      initialization/
      plots/
      simulink/
      visualizations/
```

- 简单练习不拆 `requirements/`、`src/`、`exports/`，一个文件夹即可；
- 正式共享库代码放 `matlab-project-utils/src/`，不要再放回练习项目的 `utils/`；
- 练习项目和共享库同属这个仓库，不再嵌套独立 `.git`；
- `.old/` 是历史备份，不参与当前项目，其中保留了旧练习仓库的 bundle；
- MATLAB 里使用时把用到的 `src` 加入 path，例如 `addpath('matlab-project-utils/src/plots')`。
