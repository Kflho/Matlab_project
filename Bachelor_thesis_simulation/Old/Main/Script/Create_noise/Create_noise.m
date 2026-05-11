function [Vk,Wk,simin_noise]=Create_noise()
% 生成过程噪声协方差矩阵 
sigma1_sq = 0.01^2;  % 第1维方差
sigma2_sq = 0.01^2;  % 第2维方差
sigma3_sq = 0.01^2; % 第3维方差
sigma4_sq = 0.01^2; % 第4维方差
%Wk可用Q表示
Wk = diag([sigma1_sq, sigma2_sq, sigma3_sq, sigma4_sq]);

% 生成观测噪声协方差矩阵

sigma5_sq=0.02^2; 
sigma6_sq=0.02^2; 
%Vk可用R表示
Vk = diag([sigma5_sq, sigma6_sq]);



% =========================================================================
% 函数功能：生成高斯白噪声 v_a ~ N(0, Va)，不依赖额外工具箱
% =========================================================================

% --- 1. 参数与协方差矩阵定义 ---
Ts = 1; 
total_points=1000;
% 修正后的 diag 用法：使用中括号包裹向量
Va = diag([0.003844, 0.004032]); 

% --- 2. 生成多元高斯噪声 (替代 mvnrnd) ---
% randn 生成 (total_points x 2) 的标准正态分布噪声
standard_noise = randn(total_points, 2); 

% 使用 Cholesky 分解将标准噪声转化为具有协方差 Va 的噪声
% 理论依据：若 z ~ N(0, I)，则 L*z' ~ N(0, L*L')，其中 Va = L*L'
L = chol(Va, 'lower'); 
noise_raw = (L * standard_noise')'; 

% --- 3. 时间与数据直观输出 ---
time = (0:total_points-1)' * Ts;

fprintf('\n--- 通信噪声参数报告 (基础函数实现) ---\n');
fprintf('总持续时长  : %.2f 秒 (共 %d 个时间点)\n', (total_points-1)*Ts, total_points);
fprintf('------------------------------\n');

% 直接输出噪声序列数据表格 (Time | Noise Ch1 | Noise Ch2)
%fprintf('\n生成的通信噪声序列数据 (Time | Noise Ch1 | Noise Ch2):\n');
%disp([time, noise_raw]); 

% --- 4. 封装为 Simulink 时间序列 ---
% 保持与 Create_FDIA 一致的转置格式
simin_noise = timeseries(noise_raw', time);

end