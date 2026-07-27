%% localize_stage2_fine.m  第二阶段精定位脚本
%  基于Simulink仿真数据，在粗定位锁定的故障区域内模拟切断可疑子系统 S_i 向外发送的信息，
%  循环调用 recursive_joint_filter 提取其它子系统对全局状态的交叉估计
%  x_hat_{i,k}^{(j)}。依据 Table I 的一致性判定逻辑，对比估计值与预测值，
%  最终输出确诊的故障源头子系统 ID。
%
%  依赖：
%    - recursive_joint_filter.m
%    - model_2_to_model_3_qr.m
%    - inject_fault.m
%
%  判定逻辑（Table I）：
%    若交叉估计与本地预测值一致 → 非故障源
%    若交叉估计与本地预测值不一致 → 确认为故障源

clear; clc;
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

% ---- 加载参数 ----
init_parameters;

% ---- 精定位循环 ----
% for each 可疑子系统 S_i in 锁定区域:
%     模拟切断 S_i 发送信息
%     对其它子系统 j 运行 recursive_joint_filter，获得交叉估计 x_hat_i^{(j)}
%     依据 Table I 判定一致性
%     记录判定结果

% ---- 输出最终诊断 ----
% fault_subsystem_id = ...;  % 故障源头子系统编号
