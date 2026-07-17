function [x_hat_k_k, x_hat_kp1_k, d_hat_k, Sigma_x_tilde_kp1_k, M_k, K_k, info] = ...
    Recursive_joint_filter(x_hat_km1, Sigma_x_tilde_km1, ...
                            y_k, u_k, ...
                            A_i, B_bar_i, C_i, D_bar_i, ...
                            G_i, H_i, ...
                            Sigma_w_i, Sigma_v_i)
% Recursive_joint_filter  改进型递归滤波器（单步、单子系统）
%   实现论文公式 (40)-(47) 的五步联合状态与未知输入估计。
%   基于 Gillijns & De Moor (2007) [24] 的无偏最小方差滤波器。
%
%   五步递归流程：
%     S1 (40): ỹ_{i,b,k}   = y_k - C_i·x̂_{k|k-1} - D̄_i·u_k     （有偏创新）
%     S2 (41): d̂_{i,k}     = M_{i,k} · ỹ_{i,b,k}               （未知输入估计）
%     S3 (42): ỹ_{i,ub,k}  = y_k - C_i·x̂_{k|k-1} - H_i·d̂_{i,k}  （无偏创新）
%     S4 (43): x̂_{i,k|k}   = x̂_{k|k-1} + K_{i,k} · ỹ_{i,ub,k}  （状态校正）
%     S5 (44): x̂_{i,k+1|k} = A_i·x̂_{k|k} + B̄_i·u_k + G_i·d̂_k   （一步预测）
%
%   增益计算（公式 (45)-(47)）：
%     (45): Σ_{ey} = C_i · Σ_{x̃,k|k-1} · C_i^T + Σ_{v,i}
%     (46): M_{i,k} = (H_i^T · Σ_{ey}^{-1} · H_i)^{-1} · H_i^T · Σ_{ey}^{-1}
%     (47): K_{i,k} = Σ_{x̃,k|k-1} · C_i^T · Σ_{ey}^{-1}
%
%   协方差传播（紧随公式 (47) 之后）：
%     Σ_{d̃,k}     = (H_i^T · Σ_{ey}^{-1} · H_i)^{-1}
%     Σ_{x̃,k|k}   = Σ_{x̃,k|k-1} - K_{i,k}·(Σ_{ey} - H_i·Σ_{d̃,k}·H_i^T)·K_{i,k}^T
%     Σ_{x̃,d̃,k}   = -K_{i,k} · H_i · Σ_{d̃,k}
%     Σ_{x̃,k+1|k} = [A_i, G_i] · blkdiag(Σ_{x̃,k|k}, Σ_{x̃,d̃,k}; Σ_{x̃,d̃,k}^T, Σ_{d̃,k})
%                    · [A_i, G_i]^T + Σ_{w,i}
%
%   Inputs:
%       x_hat_km1         - 上一步预测状态 x̂_{i,k|k-1}（n_x × 1）
%       Sigma_x_tilde_km1 - 上一步预测误差协方差 Σ_{x̃,k|k-1}（n_x × n_x）
%       y_k               - 当前测量输出（n_y × 1），无传感器子系统传 []
%       u_k               - 当前输入（n_u × 1）
%       A_i               - 局部状态矩阵（n_x × n_x）
%       B_bar_i           - 有效输入矩阵（n_x × n_u）
%       C_i               - 局部输出矩阵（n_y × n_x），无传感器传 []
%       D_bar_i           - 有效前馈矩阵（n_y × n_u），无传感器传 []
%       G_i               - 未知输入驱动矩阵（n_x × dim_d）
%       H_i               - 未知输入→输出映射（n_y × dim_d）
%       Sigma_w_i         - 过程噪声协方差（n_x × n_x）
%       Sigma_v_i         - 测量噪声协方差（n_y × n_y）
%
%   Outputs:
%       x_hat_k_k          - 校正状态估计 x̂_{i,k|k}（n_x × 1）
%       x_hat_kp1_k        - 一步预测 x̂_{i,k+1|k}（n_x × 1）
%       d_hat_k            - 未知输入估计 d̂_{i,k}（dim_d × 1）
%       Sigma_x_tilde_kp1_k - 预测误差协方差 Σ_{x̃,k+1|k}（n_x × n_x）
%       M_k                - 未知输入滤波器增益 M_{i,k}（dim_d × n_y）
%       K_k                - 状态滤波器增益 K_{i,k}（n_x × n_y）
%       info               - 状态结构体（字段见下文）
%
%   info 字段：
%       converged    - 滤波器是否正常收敛（逻辑值）
%       rank_ok      - 秩条件是否满足
%       y_tilde_b    - 有偏创新（公式 40）
%       y_tilde_ub   - 无偏创新（公式 42）
%       Sigma_ey     - 创新协方差（公式 45）
%       Sigma_d_tilde - 未知输入估计误差协方差
%
%   Example:
%       [x_k_k, x_kp1_k, d_k, S_kp1, M_k, K_k, info] = ...
%           Recursive_joint_filter(x_prev, S_prev, y, u, ...
%               A{1}, B_bar{1}, C{1}, D_bar{1}, G{1}, H{1}, ...
%               Sigma_w{1}, Sigma_v{1});

%% ========================================================================
%  0. 初始化与维度推断
% ========================================================================

n_x = size(A_i, 1);
n_u = length(u_k);
dim_d = size(G_i, 2);

% 判断是否有传感器
if isempty(C_i) || isempty(y_k)
    has_measurement = false;
    n_y = 0;
else
    has_measurement = true;
    n_y = length(y_k);
end

% 默认输出初始化
x_hat_k_k    = x_hat_km1;                   % 无测量时保持预测
x_hat_kp1_k  = A_i * x_hat_km1 + B_bar_i * u_k;  % 开环预测
d_hat_k      = zeros(dim_d, 1);
M_k          = zeros(dim_d, n_y);
K_k          = zeros(n_x, n_y);

info = struct();
info.converged   = true;
info.rank_ok     = false;
info.y_tilde_b   = zeros(n_y, 1);
info.y_tilde_ub  = zeros(n_y, 1);
info.Sigma_ey    = [];
info.Sigma_d_tilde = [];

%% ========================================================================
%  0a. 无传感器子系统：仅做开环预测
% ========================================================================
if ~has_measurement
    % 纯状态预测（公式 (44) 去掉 d̂ 项）
    x_hat_kp1_k = A_i * x_hat_km1 + B_bar_i * u_k;

    % 协方差预测（公式中 [A_i, G_i] 部分的简化）
    Sigma_x_tilde_kp1_k = A_i * Sigma_x_tilde_km1 * A_i' + Sigma_w_i;

    info.converged = true;
    return;
end

%% ========================================================================
%  0b. 检查秩条件
% ========================================================================
tol = 1e-12;

if dim_d == 0
    % 无未知输入 → 退化为标准 Kalman 滤波
    use_unknown_input = false;
else
    rank_H = rank(H_i, tol);
    if rank_H < dim_d
        % 秩条件不满足：H_i 无法完整观测 d_i
        warning(['Recursive_joint_filter: 子系统 H_i 的秩 (%d) < dim(d_i) (%d)。' ...
            '退化为标准 Kalman 滤波。'], rank_H, dim_d);
        use_unknown_input = false;
    else
        use_unknown_input = true;
    end
end

%% ========================================================================
%  1. 公式 (45)：创新协方差 Σ_{ey}
% ========================================================================

Sigma_ey = C_i * Sigma_x_tilde_km1 * C_i' + Sigma_v_i;

% 正则化：保证数值可逆
Sigma_ey = (Sigma_ey + Sigma_ey') / 2;               % 对称化
Sigma_ey = Sigma_ey + tol * eye(n_y);                % 防止奇异

info.Sigma_ey = Sigma_ey;

%% ========================================================================
%  2. 公式 (47)：Kalman 状态增益 K_{i,k}
% ========================================================================

K_k = Sigma_x_tilde_km1 * C_i' / Sigma_ey;           % n_x × n_y

%% ========================================================================
%  3. 公式 (40)：有偏创新 ỹ_{i,b,k}
% ========================================================================

y_tilde_b = y_k - C_i * x_hat_km1 - D_bar_i * u_k;   % n_y × 1
info.y_tilde_b = y_tilde_b;

%% ========================================================================
%  4. 公式 (46) + (41)：未知输入估计
% ========================================================================

if use_unknown_input && dim_d > 0

    % ---- 公式 (46)：未知输入增益 M_{i,k} ----
    % M = (H' · Σ_{ey}^{-1} · H)^{-1} · H' · Σ_{ey}^{-1}
    Ht_Sinv = H_i' / Sigma_ey;                        % dim_d × n_y
    Ht_Sinv_H = Ht_Sinv * H_i;                        % dim_d × dim_d

    % 正则化
    Ht_Sinv_H = (Ht_Sinv_H + Ht_Sinv_H') / 2;
    Ht_Sinv_H = Ht_Sinv_H + tol * eye(dim_d);

    M_k = Ht_Sinv_H \ Ht_Sinv;                        % dim_d × n_y

    % ---- 公式 (41)：未知输入估计 ----
    d_hat_k = M_k * y_tilde_b;                        % dim_d × 1

    % ---- 未知输入误差协方差 ----
    Sigma_d_tilde = inv(Ht_Sinv_H);                   % dim_d × dim_d
    Sigma_d_tilde = (Sigma_d_tilde + Sigma_d_tilde') / 2;
    info.Sigma_d_tilde = Sigma_d_tilde;

    % ---- 公式 (42)：无偏创新 ----
    y_tilde_ub = y_k - C_i * x_hat_km1 - H_i * d_hat_k;
    % 等价于：y_tilde_ub = y_tilde_b - H_i * d_hat_k

    info.rank_ok = true;

else
    % ---- 退化为标准 Kalman：无未知输入估计 ----
    d_hat_k = zeros(dim_d, 1);
    M_k = zeros(dim_d, n_y);

    % 无偏创新 = 有偏创新（无非 H_i 项）
    y_tilde_ub = y_tilde_b;

    info.rank_ok = false;
end

info.y_tilde_ub = y_tilde_ub;

%% ========================================================================
%  5. 公式 (43)：最小方差状态校正
% ========================================================================

x_hat_k_k = x_hat_km1 + K_k * y_tilde_ub;

%% ========================================================================
%  6. 公式 (44)：一步前向预测
% ========================================================================

x_hat_kp1_k = A_i * x_hat_k_k + B_bar_i * u_k + G_i * d_hat_k;

%% ========================================================================
%  7. 协方差传播
% ========================================================================

if use_unknown_input && dim_d > 0

    % ---- 7a. 校正误差协方差 Σ_{x̃,k|k} ----
    % Σ_{x̃,k|k} = Σ_{x̃,k|k-1} - K·(Σ_{ey} - H·Σ_{d̃}·H')·K'
    Sigma_x_tilde_k_k = Sigma_x_tilde_km1 ...
        - K_k * (Sigma_ey - H_i * Sigma_d_tilde * H_i') * K_k';
    Sigma_x_tilde_k_k = (Sigma_x_tilde_k_k + Sigma_x_tilde_k_k') / 2;

    % ---- 7b. 交叉协方差 Σ_{x̃,d̃,k} ----
    Sigma_xd_tilde = -K_k * H_i * Sigma_d_tilde;       % n_x × dim_d

    % ---- 7c. 预测误差协方差 Σ_{x̃,k+1|k} ----
    % Σ_{x̃,k+1|k} = [A, G] · [Σ_{x̃,k|k}, Σ_{x̃,d̃}; Σ_{x̃,d̃}', Σ_{d̃}] · [A, G]' + Σ_w
    Aug = [A_i, G_i];                                  % n_x × (n_x + dim_d)
    blk_cov = [Sigma_x_tilde_k_k, Sigma_xd_tilde; ...
               Sigma_xd_tilde',   Sigma_d_tilde];      % (n_x+dim_d) × (n_x+dim_d)

    Sigma_x_tilde_kp1_k = Aug * blk_cov * Aug' + Sigma_w_i;
    Sigma_x_tilde_kp1_k = (Sigma_x_tilde_kp1_k + Sigma_x_tilde_kp1_k') / 2;

else
    % ---- 退化为标准 Kalman 协方差传播 ----

    % 校正协方差
    Sigma_x_tilde_k_k = Sigma_x_tilde_km1 ...
        - K_k * Sigma_ey * K_k';
    Sigma_x_tilde_k_k = (Sigma_x_tilde_k_k + Sigma_x_tilde_k_k') / 2;

    % 预测协方差
    Sigma_x_tilde_kp1_k = A_i * Sigma_x_tilde_k_k * A_i' + Sigma_w_i;
    Sigma_x_tilde_kp1_k = (Sigma_x_tilde_kp1_k + Sigma_x_tilde_kp1_k') / 2;

end

%% ========================================================================
%  8. 收敛性检查
% ========================================================================

% 检查协方差是否半正定
if min(real(eig(Sigma_x_tilde_kp1_k))) < -1e-10
    warning('Recursive_joint_filter: 预测协方差非半正定，可能数值不稳定。');
    info.converged = false;
end

% 检查状态是否发散
if any(isnan(x_hat_kp1_k)) || any(isinf(x_hat_kp1_k))
    warning('Recursive_joint_filter: 状态估计发散。');
    info.converged = false;
    x_hat_kp1_k = A_i * x_hat_km1 + B_bar_i * u_k;  % 回退到开环
    Sigma_x_tilde_kp1_k = A_i * Sigma_x_tilde_km1 * A_i' + Sigma_w_i;
end

end
