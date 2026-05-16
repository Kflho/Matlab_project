% batch_experiments.m
clc; close all; clear;

% ===== 添加路径 =====
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_FDIA')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_noise')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_shoukong')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Filter_design')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\POMDP')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Plot')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Calculate\')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Visualization')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Simulink')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Script\Experiment')

% ===== 全局水印库（所有实验共用）=====
watermarks(1).name = '粗选弱'; watermarks(1).Cw = [1 1 1 1; 1 1 1 1]; watermarks(1).Dw = [0.9 0; 0 0.9];
watermarks(2).name = '粗选强'; watermarks(2).Cw = [0.5 0.5 0.5 0.5; 0.5 0.5 0.5 0.5]; watermarks(2).Dw = [0.5 0; 0 0.5];
watermarks(3).name = '最优弱'; watermarks(3).Cw = [-0.0604 -0.1805 -0.2914 -0.5203; -0.2819 0.0678 -0.8082 0.0340]; watermarks(3).Dw = [0.1420 0; 0 0.1730];%0.2558
watermarks(4).name = '最优强'; watermarks(4).Cw = [0.0726 -0.1858 0.1483 -0.5082; -0.1287 -0.0427 -0.3894 -0.2472]; watermarks(4).Dw = [0.0709 0; 0 0.1814];%0.0401
watermarks(5).name = '变态强'; watermarks(5).Cw = [-0.0473 -0.0465 -0.2175 -0.1587; -0.1399 0.1533 -0.3775 0.3554]; watermarks(5).Dw = [0.0851 0; 0 0.0641];
attack_target=[6.35;6.2];
attack_len=200;
% ======================== 实验1 ========================
exp1.name = '01_FDIA_destruction';
exp1.start_time_FDIA = 250;
exp1.FDIA_length = 750;
exp1.start_time_QW = 2000;            % 不嵌入水印
exp1.watermark_idx = 0;               % 0 表示无水印
exp1.d_target = attack_target;
exp1.ramp_len = 100 ;
exp1.sign_vec = [1; 1];
exp1.plot_residual = true;
exp1.plot_liquid_level = true;
exp1.plot_residual_square = true;
exp1.plot_performance = true;
exp1.plot_attack_energy = true;
exp1.threshold_value = 1;
exp1.threshold_label = '|r|_{max}';
exp1.threshold_square_val = 0.1;
exp1.threshold_square_lbl = 'epsilon_{r}';

% ======================== 实验2 ========================
exp2 = exp1;
exp2.name = '02_Coarse_watermark_weak';
exp2.start_time_QW = 0;
exp2.watermark_idx = 1;                % 粗选弱

% ======================== 实验3 ========================
exp3 = exp1;
exp3.name = '03_Optimal_weak_watermark';
exp3.start_time_QW = 0;
exp3.watermark_idx = 3;                % 最优弱

% ======================== 实验4 ========================
exp4 = exp1;
exp4.name = '04_Optimal_strong_watermark';
exp4.start_time_QW = 0;
exp4.watermark_idx = 4;                % 最优强/变态强

% ======================== 实验5 ========================
exp5.name = '05_Attack_energy';
exp5.start_time_FDIA = 0;
exp5.FDIA_length = 150;
exp5.start_time_QW = 2000;
exp5.watermark_idx = 0;
exp5.d_target = attack_target;
exp5.ramp_len = attack_len;
exp5.sign_vec = [1; 1];
exp5.plot_residual = false;
exp5.plot_liquid_level = false;
exp5.plot_residual_square = false;
exp5.plot_performance = false;
exp5.plot_attack_energy = true;

% ======================== 实验6：性能影响参数变化图 ========================
exp6_NoWatermark = exp1;
exp6_NoWatermark.name = '06_Performance_No_watermark';
exp6_NoWatermark.start_time_QW = 2000;
exp6_NoWatermark.watermark_idx = 0;
exp6_NoWatermark.plot_residual = false;
exp6_NoWatermark.plot_liquid_level = false;
exp6_NoWatermark.plot_residual_square = false;
exp6_NoWatermark.plot_performance = true;
exp6_NoWatermark.plot_attack_energy = false;

exp6_OptimalWeak = exp6_NoWatermark;
exp6_OptimalWeak.name = '06_Performance_Optimal_weak';
exp6_OptimalWeak.start_time_QW = 0;
exp6_OptimalWeak.watermark_idx = 3;

exp6_OptimalStrong = exp6_NoWatermark;
exp6_OptimalStrong.name = '06_Performance_Optimal_strong';
exp6_OptimalStrong.start_time_QW = 0;
exp6_OptimalStrong.watermark_idx = 4;

% ======================== 实验7：长期性能损失统计 ========================
% 公有参数
stat_duration = 2000;
common_fields7 = struct(...
    'calc_stats', true, ...
    'stat_sim_duration', stat_duration, ...
    'd_target', attack_target, ...
    'ramp_len', attack_len, ...
    'sign_vec', [1;1], ...
    'plot_residual', false, ...
    'plot_liquid_level', false, ...
    'plot_residual_square', false, ...
    'plot_performance', false, ...
    'plot_attack_energy', false);

% 1) 不攻击_无水印
exp7_NoAttack_NoWatermark = common_fields7;
exp7_NoAttack_NoWatermark.name = '07_Stats_NoAttack_NoWatermark';
exp7_NoAttack_NoWatermark.start_time_FDIA = stat_duration + 1000;
exp7_NoAttack_NoWatermark.FDIA_length = 100;
exp7_NoAttack_NoWatermark.watermark_idx = 0;
exp7_NoAttack_NoWatermark.start_time_QW = stat_duration + 1000;

% 2) 受攻击_无水印
exp7_UnderAttack_NoWatermark = common_fields7;
exp7_UnderAttack_NoWatermark.name = '07_Stats_UnderAttack_NoWatermark';
exp7_UnderAttack_NoWatermark.start_time_FDIA = 0;
exp7_UnderAttack_NoWatermark.FDIA_length = stat_duration;
exp7_UnderAttack_NoWatermark.watermark_idx = 0;
exp7_UnderAttack_NoWatermark.start_time_QW = stat_duration + 1000;

% 3) 不攻击_粗选弱
exp7_NoAttack_CoarseWeak = common_fields7;
exp7_NoAttack_CoarseWeak.name = '07_Stats_NoAttack_CoarseWeak';
exp7_NoAttack_CoarseWeak.start_time_FDIA = stat_duration + 1000;
exp7_NoAttack_CoarseWeak.FDIA_length = 100;
exp7_NoAttack_CoarseWeak.watermark_idx = 1;
exp7_NoAttack_CoarseWeak.start_time_QW = 0;

% 4) 受攻击_粗选弱
exp7_UnderAttack_CoarseWeak = common_fields7;
exp7_UnderAttack_CoarseWeak.name = '07_Stats_UnderAttack_CoarseWeak';
exp7_UnderAttack_CoarseWeak.start_time_FDIA = 0;
exp7_UnderAttack_CoarseWeak.FDIA_length = stat_duration;
exp7_UnderAttack_CoarseWeak.watermark_idx = 1;
exp7_UnderAttack_CoarseWeak.start_time_QW = 0;

% 5) 不攻击_粗选强
exp7_NoAttack_CoarseStrong = common_fields7;
exp7_NoAttack_CoarseStrong.name = '07_Stats_NoAttack_CoarseStrong';
exp7_NoAttack_CoarseStrong.start_time_FDIA = stat_duration + 1000;
exp7_NoAttack_CoarseStrong.FDIA_length = 100;
exp7_NoAttack_CoarseStrong.watermark_idx = 2;
exp7_NoAttack_CoarseStrong.start_time_QW = 0;

% 6) 受攻击_粗选强
exp7_UnderAttack_CoarseStrong = common_fields7;
exp7_UnderAttack_CoarseStrong.name = '07_Stats_UnderAttack_CoarseStrong';
exp7_UnderAttack_CoarseStrong.start_time_FDIA = 0;
exp7_UnderAttack_CoarseStrong.FDIA_length = stat_duration;
exp7_UnderAttack_CoarseStrong.watermark_idx = 2;
exp7_UnderAttack_CoarseStrong.start_time_QW = 0;

% 7) 不攻击_最优弱
exp7_NoAttack_OptimalWeak = common_fields7;
exp7_NoAttack_OptimalWeak.name = '07_Stats_NoAttack_OptimalWeak';
exp7_NoAttack_OptimalWeak.start_time_FDIA = stat_duration + 1000;
exp7_NoAttack_OptimalWeak.FDIA_length = 100;
exp7_NoAttack_OptimalWeak.watermark_idx = 3;
exp7_NoAttack_OptimalWeak.start_time_QW = 0;

% 8) 受攻击_最优弱
exp7_UnderAttack_OptimalWeak = common_fields7;
exp7_UnderAttack_OptimalWeak.name = '07_Stats_UnderAttack_OptimalWeak';
exp7_UnderAttack_OptimalWeak.start_time_FDIA = 0;
exp7_UnderAttack_OptimalWeak.FDIA_length = stat_duration;
exp7_UnderAttack_OptimalWeak.watermark_idx = 3;
exp7_UnderAttack_OptimalWeak.start_time_QW = 0;

% 9) 不攻击_最优强
exp7_NoAttack_OptimalStrong = common_fields7;
exp7_NoAttack_OptimalStrong.name = '07_Stats_NoAttack_OptimalStrong';
exp7_NoAttack_OptimalStrong.start_time_FDIA = stat_duration + 1000;
exp7_NoAttack_OptimalStrong.FDIA_length = 100;
exp7_NoAttack_OptimalStrong.watermark_idx = 4;
exp7_NoAttack_OptimalStrong.start_time_QW = 0;

% 10) 受攻击_最优强
exp7_UnderAttack_OptimalStrong = common_fields7;
exp7_UnderAttack_OptimalStrong.name = '07_Stats_UnderAttack_OptimalStrong';
exp7_UnderAttack_OptimalStrong.start_time_FDIA = 0;
exp7_UnderAttack_OptimalStrong.FDIA_length = stat_duration;
exp7_UnderAttack_OptimalStrong.watermark_idx = 4;
exp7_UnderAttack_OptimalStrong.start_time_QW = 0;

% ======================== 实验8：残差阈值计算 ========================
common_fields8 = struct(...
    'calc_threshold', true, ...
    'stat_sim_duration', 2000, ...
    'start_time_FDIA', 2000+1000, ...
    'FDIA_length', 100, ...
    'd_target', attack_target, ...
    'ramp_len', attack_len, ...
    'sign_vec', [1;1], ...
    'plot_residual', false, ...
    'plot_liquid_level', false, ...
    'plot_residual_square', false, ...
    'plot_performance', false, ...
    'plot_attack_energy', false);

% 无水印
exp8_NoWatermark = common_fields8;
exp8_NoWatermark.name = '08_Thresholds_No_watermark';
exp8_NoWatermark.watermark_idx = 0;
exp8_NoWatermark.start_time_QW = 2000+1000;  % 远大于仿真时间

% 最优弱
exp8_OptimalWeak = common_fields8;
exp8_OptimalWeak.name = '08_Thresholds_Weak';
exp8_OptimalWeak.watermark_idx = 3;
exp8_OptimalWeak.start_time_QW = 0;

% 最优强
exp8_OptimalStrong = common_fields8;
exp8_OptimalStrong.name = '08_Thresholds_Strong';
exp8_OptimalStrong.watermark_idx = 4;
exp8_OptimalStrong.start_time_QW = 0;




% ======================== 实验9：阈值对比 + 残差能量图 ========================
% 定义三个子实验（使用实验10得到的opt_kappa）

% 9a 最优弱水印
exp9a.name = '09a_Threshold_Comparison_OptimalWeak';
exp9a.calc_detection_compare = true;
% exp9a.kappa = opt_kappa(2);
exp9a.original_epsilon = 1;
exp9a.watermark_idx = 3;
exp9a.start_time_FDIA = 250;
exp9a.FDIA_length = 750;
exp9a.start_time_QW = 0;
exp9a.d_target = attack_target;
exp9a.ramp_len = attack_len;
exp9a.sign_vec = [1; 1];
exp9a.attack_start = 250;
exp9a.attack_end = 1000;
exp9a.plot_residual = false;
exp9a.plot_liquid_level = false;
exp9a.plot_residual_square = true;
exp9a.plot_performance = false;
exp9a.plot_attack_energy = false;
exp9a.threshold_square_val = 0;         % 占位
exp9a.threshold_square_lbl = '最优阈值';

% 9b 最优强水印
exp9b = exp9a;
exp9b.name = '09b_Threshold_Comparison_OptimalStrong';
exp9b.watermark_idx = 4;
exp9b.original_epsilon = 0.1;
% exp9b.kappa = opt_kappa(3);

% 9c 无水印
exp9c = exp9a;
exp9c.name = '09c_Threshold_Comparison_NoWatermark';
exp9c.watermark_idx = 0;
exp9c.start_time_QW = 2000;
exp9c.original_epsilon = 0.1;
% exp9c.kappa = opt_kappa(1);


%% ======================== 实验10：贪心最优阈值 ========================
% 公共仿真参数（三个子实验共用）
common10.start_time_FDIA = 250;
common10.FDIA_length = 750;
common10.d_target = attack_target;
common10.ramp_len = attack_len;
common10.sign_vec = [1; 1];
common10.attack_start = 250;
common10.attack_end = 1000;
common10.cf = 1;
common10.cm = 1;
common10.lambda = 0;

% --- 子实验10a：无水印 ---
exp10_NoWatermark = common10;
exp10_NoWatermark.scheme_name = '无水印';
exp10_NoWatermark.watermark_idx = 0;
exp10_NoWatermark.start_time_QW = 2000;   % 不触发水印

% --- 子实验10b：弱水印 ---
exp10_OptimalWeak = common10;
exp10_OptimalWeak.scheme_name = '弱水印';
exp10_OptimalWeak.watermark_idx = 3;
exp10_OptimalWeak.start_time_QW = 0;

% --- 子实验10c：强水印 ---
exp10_OptimalStrong = common10;
exp10_OptimalStrong.scheme_name = '强水印';
exp10_OptimalStrong.watermark_idx = 4;
exp10_OptimalStrong.start_time_QW = 0;






% ======================== 逐个运行实验 ========================

% % % % ----- 实验1 -----
% run_experiment(exp1,watermarks);
% close all;
% 
% % % % ----- 实验2 -----
% run_experiment(exp2,watermarks);
% close all;
% 
% % % % ----- 实验3 -----
% run_experiment(exp3,watermarks);
% close all;
% 
% % % ----- 实验4 -----
% run_experiment(exp4,watermarks);
% close all;
% 
% % % % ----- 实验5 -----
% run_experiment(exp5,watermarks);
% close all;
% 
% % % % ----- 实验6 -----
% run_experiment(exp6_NoWatermark,watermarks);
% close all;
% run_experiment(exp6_OptimalWeak,watermarks);
% close all;
% run_experiment(exp6_OptimalStrong,watermarks);
% close all;
% % 
% ----- 实验7 -----
% run_experiment_7(exp7_NoAttack_NoWatermark,watermarks);
% close all;
% run_experiment_7(exp7_UnderAttack_NoWatermark,watermarks);
% close all;
% run_experiment_7(exp7_NoAttack_CoarseWeak,watermarks);
% close all;
% run_experiment_7(exp7_UnderAttack_CoarseWeak,watermarks);
% close all;
% run_experiment_7(exp7_NoAttack_CoarseStrong,watermarks);
% close all;
% run_experiment_7(exp7_UnderAttack_CoarseStrong,watermarks);
% close all;
% run_experiment_7(exp7_NoAttack_OptimalWeak,watermarks);
% close all;
% run_experiment_7(exp7_UnderAttack_OptimalWeak,watermarks);
% close all;
% run_experiment_7(exp7_NoAttack_OptimalStrong,watermarks);
% close all;
% run_experiment_7(exp7_UnderAttack_OptimalStrong,watermarks);
% close all;
% % % % 
% % % % % ----- 实验8 -----
% run_experiment_8(exp8_NoWatermark,watermarks);
% close all;
% run_experiment_8(exp8_OptimalWeak,watermarks);
% close all;
% run_experiment_8(exp8_OptimalStrong,watermarks);
% close all;
% % % 
% % % ----- 实验9 ----- （保留图窗，不关闭）
% run_experiment_9(exp9a,watermarks);   % 图窗保持打开
% run_experiment_9(exp9b,watermarks);   % 图窗保持打开
% run_experiment_9(exp9c,watermarks);   % 图窗保持打开
% % 
% % % 实验9完成后，可手动关闭所有图窗，或保留以便截图
% % % close all;
% % 
% % % % % % ----- 实验10 -----
% run_experiment_10(exp10_NoWatermark, watermarks);
% run_experiment_10(exp10_OptimalWeak,   watermarks);
% run_experiment_10(exp10_OptimalStrong, watermarks);

% % %% 实验11：基于帕累托最优的弱/强水印设计（不加入 exp_list）
% % % fprintf('\n===== 实验11：帕累托水印优化 =====\n');
% % run_experiment_11();
% % % 可根据需要，从保存的 .mat 文件中读取结果用于后续实验
% % 
% % 
% % 实验12
% run_experiment_12(watermarks,attack_target,attack_len);

%% 实验13
run_experiment_13(30);