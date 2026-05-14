function simin = Create_FDIA_MinEnergy_LP_fixedsign_par(A, C, K_KF, total_steps, d_target, sign_vec, start_time, Ts, ramp_steps)
% 基于最小能量的攻击序列生成（并行加速版，固定符号+斜坡）
%
% 输入：
%   A, C, K_KF : 系统矩阵、观测矩阵、稳态卡尔曼增益
%   total_steps : 攻击序列总长度（步数）
%   d_target    : 目标偏移（稳态值），列向量，长度 = 传感器数 m
%   sign_vec    : 每通道偏移符号，+1 或 -1，列向量，长度 = m
%   start_time  : 攻击开始时间（秒）
%   Ts          : 采样周期（秒）
%   ramp_steps  : 斜坡步数（可选，默认0为恒定偏移）
%
% 需要 Parallel Computing Toolbox，自动启动并行池

if nargin < 9, ramp_steps = 0; end
if nargin < 8, Ts = 1; end
if nargin < 7, start_time = 0; end

n = size(A, 1);
m = size(C, 1);

d_target = d_target(:);
sign_vec = sign_vec(:);
if length(d_target) ~= m || length(sign_vec) ~= m
    error('d_target 和 sign_vec 长度必须等于传感器数 m = %d', m);
end
if any(abs(sign_vec) ~= 1)
    error('sign_vec 元素必须为 +1 或 -1');
end

% ---- 构造时变期望偏移矩阵 d_mat (m × total_steps) ----
if ramp_steps > 0 && ramp_steps < total_steps
    ramp = linspace(0, 1, ramp_steps);
    d_ramp = d_target * ramp;
    d_steady = d_target * ones(1, total_steps - ramp_steps);
    d_mat = [d_ramp, d_steady];
else
    d_mat = d_target * ones(1, total_steps);
end

% ---- 预计算状态映射矩阵 M_cell （串行） ----
A_cl = A - K_KF * C * A;
M_cell = cell(total_steps, 1);
for t = 1:total_steps
    M_t = zeros(n, m*t);
    for i = 1:t
        cols = (i-1)*m + (1:m);
        M_t(:, cols) = (A_cl^(t-i)) * K_KF;
    end
    M_cell{t} = M_t;
end

num_eps = m * total_steps;
total_vars = 2 * num_eps;          % 变量：ε_pos, ε_neg

% ---- 打开并行池 ----
if isempty(gcp('nocreate'))
    parpool;
end

% ---- 并行构造每个时刻的约束块 ----
% A_t 为 m × total_vars 稀疏矩阵，b_t 为 m × 1
A_cell = cell(total_steps, 1);
b_cell = cell(total_steps, 1);

parfor t = 1:total_steps
    M_t = M_cell{t};
    C_M_t = C * M_t;                     % m × (m*t)
    cols_eps_t = 1 : m*t;                % ε_pos 的列范围
    d_t_vec = d_mat(:, t);               % 当前期望偏移 (m×1)

    % 初始化稀疏矩阵 (m × total_vars)
    A_t = sparse(m, total_vars);
    b_t = zeros(m, 1);

    for j = 1:m
        % 系数行: -sign(j) * [C_M_t(j,:),  -C_M_t(j,:)]
        coeff = -sign_vec(j) * [C_M_t(j, :), -C_M_t(j, :)];
        % 左半部分对应 ε_pos, 右半对应 ε_neg
        A_t(j, cols_eps_t) = coeff(1 : m*t);
        A_t(j, cols_eps_t + num_eps) = coeff(m*t+1 : 2*m*t);
        b_t(j) = -d_t_vec(j);
    end
    A_cell{t} = A_t;
    b_cell{t} = b_t;
end

% ---- 合并所有约束块 ----
Aineq = vertcat(A_cell{:});
bineq = vertcat(b_cell{:});

% ---- 变量下界 ----
lb = zeros(total_vars, 1);

% ---- 求解线性规划 ----
f = ones(total_vars, 1);
options = optimoptions('linprog', 'Display', 'off', 'Algorithm', 'dual-simplex');
[x, fval, exitflag] = linprog(f, Aineq, bineq, [], [], lb, [], options);
if exitflag <= 0
    options.Algorithm = 'interior-point';
    [x, fval, exitflag] = linprog(f, Aineq, bineq, [], [], lb, [], options);
end
if exitflag <= 0
    error('攻击序列生成失败，请降低期望偏移或调整符号。');
end

% ---- 提取攻击序列 ----
eps_pos = x(1:num_eps);
eps_neg = x(num_eps+1:end);
eps_vec = eps_pos - eps_neg;
epsilon = reshape(eps_vec, [m, total_steps]);

% ---- 验证理论偏移 ----
fprintf('攻击序列生成成功 (并行LP, 斜坡=%d步)\n', ramp_steps);
% for t = 1:total_steps
%     eps_t = eps_vec(1:(m*t));
%     delta_m = M_cell{t} * eps_t;
%     C_delta_m = C * delta_m;
%     fprintf('t=%-3d: 期望偏移 [%s], 理论偏移 [%s]\n', t, ...
%             num2str(d_mat(:,t)', '%.4f  '), num2str(C_delta_m', '%.4f  '));
% end
fprintf('攻击信号总能量(L1): %.4f\n', fval);

% ---- 生成 Simulink 时间序列 ----
attack_time = (0:total_steps-1)' * Ts + start_time;
if start_time > 0
    full_time = [0; attack_time];
    full_data = [zeros(m,1), epsilon];
else
    full_time = attack_time;
    full_data = epsilon;
end
simin = timeseries(full_data', full_time);
simin.Name = 'Attack_Signal';
simin.DataInfo.Interpolation = tsdata.interpolation('zoh');
end