%% 最优水印滤波器参数设计 (适配 yj=6x1, y=2x1)
clear; clc;

% --- 1. 系统维度与基础参数设置 ---
n = 4;   % 状态 x 的维度
m = 2;   % 输入 u 的维度
p = 2;   % 测量输出 y 的维度
nyj = 6; % 性能输出 yj 的维度 (4状态 + 2控制)

% 载入或定义系统矩阵 (此处为示例，请替换为你的物理模型数值)
G = randn(n,n); H = randn(n,m); C = randn(p,n);
K = randn(m,n); L = randn(n,p);

% --- 2. 水印嵌入器/移除器固定部分 (根据截图 de5332.png) ---
% x_w(k+1) = (G - LC - HK)x_w(k) + Ly(k)
Aw = G - L*C - H*K;
Bw = L;

% --- 3. 性能权重与设计指标 (根据截图 dd8bc5.png) ---
epsilon_r = 1.2; % 残差检测阈值
epsilon_a = 5.0; % 攻击能量上界

% 构造 Q_half (4x4) 和 R_half (2x2)
Q_half = diag([0.806, 0.787, 5.556, 7.143]); 
R_half = diag([0.813, 0.804]);

% --- 4. YALMIP 决策变量定义 ---
P = sdpvar(2*n, 2*n);       % 扩增系统的 Lyapunov 矩阵
gamma = sdpvar(1, 1);       % 对应 epsilon_r 的性能影响因子
gamma_a = sdpvar(1, 1);     % 对应 epsilon_a 的攻击影响因子
Gx = sdpvar(p, n);          % 待设计的滤波器增益 Gamma_x
Gy = sdpvar(p, p);          % 待设计的滤波器增益 Gamma_y

% --- 5. 构造扩增系统闭环矩阵 (A_bar) ---
% 状态向量 xi = [x; x_w]
A_cl = [G, -H*K; Bw*C, Aw]; 

% --- 6. 构造性能输出映射 (yj = Cj_bar * xi + Dj_bar * u) ---
% 目标是将 yj 映射为 [Q_half*x; R_half*u]，维度为 6x1
Cj_bar = [Q_half, zeros(4,4);      % 映射到前4行 (状态偏差)
          zeros(2,4), zeros(2,4)]; % 后2行由控制输入决定

Dj_bar = [zeros(4,m);              % 状态项不受控制直接影响
          R_half];                 % 映射到后2行 (控制能耗)

% --- 7. 构造 LMI 约束 (根据 Lemma 3.1 公式 12) ---
% R_mat 包含 Lyapunov 稳定性和扰动传递特性
R_mat = [A_cl'*P*A_cl - P, A_cl'*P*Bw; Bw'*P*A_cl, Bw'*P*Bw];

% 构造核心 LMI (使用 Schur 补将二次项线性化)
% 注意：右下角必须为 gamma * eye(6) 以适配 yj 的 6 维
LMI = [ R_mat + [zeros(2*n), zeros(2*n,p); zeros(p,2*n), -gamma_a*eye(p)], [Cj_bar, Dj_bar]'; ...
        [Cj_bar, Dj_bar], -gamma*eye(nyj) ] <= 0;

Constraints = [LMI, P >= 1e-6*eye(2*n), gamma >= 0, gamma_a >= 0];

% --- 8. 优化求解 ---
Objective = epsilon_r * gamma + epsilon_a * gamma_a;
options = sdpsettings('solver', 'sedumi', 'verbose', 1); % 需安装 SeDuMi
sol = optimize(Constraints, Objective, options);

% --- 9. 结果处理 ---
if sol.problem == 0
    final_Gx = value(Gx);
    final_Gy = value(Gy);
    opt_val = value(Objective);
    fprintf('最优设计成功！\n性能损失上界 gamma_total = %f\n', opt_val);
else
    fprintf('求解失败，错误代码: %d。请检查模型稳定性或参数范围。\n', sol.problem);
end