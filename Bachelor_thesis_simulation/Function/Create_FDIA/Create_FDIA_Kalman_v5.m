function simin = Create_FDIA_Kalman_v5(A, C, K, Gamma, delta_z_max, total_steps, start_time, Ts)
% A, C, K, Gamma: 系统矩阵与卡尔曼增益
% delta_z_max: 残差阈值
% total_steps: 攻击序列本身的长度（步数）
% start_time: 攻击开始的物理时间（秒）
% Ts: 采样周期（秒），默认为 1

if nargin < 8, Ts = 1; end
if nargin < 7, start_time = 0; end

n = size(A, 1); 

%% 1. 筛选满足定理 2 的特征值（包含降级回退机制）
[V, D] = eig(A);
eigenvalues = diag(D);

% 提前构造可达性矩阵 R
A_cl = A - K * C * A;
B_att = -K * Gamma;
R = [];
for i = 0:n-1
    R = [R, (A_cl^i) * B_att];
end

% 按模长排序，优先尝试最具破坏力的极点（从大到小）
[~, sorted_indices] = sort(abs(eigenvalues), 'descend');

valid_target_idx = -1;
fallback_idx = -1; % 用于记录降级方案

for idx = sorted_indices'
    lam = eigenvalues(idx);
    vec = V(:, idx);
    
    % 仅考虑实数极点 (虚部极小)
    if abs(imag(lam)) > 1e-6
        continue; 
    end
    
    lam = real(lam);
    vec = real(vec);
    
    % --- 严格校验定理 2 的必要条件 ---
    % 条件 1: Cv 必须在 Gamma 的列空间内 (隐蔽性)
    y_star_test = pinv(Gamma) * (C * vec);
    err1 = norm(Gamma * y_star_test - C * vec);
    
    % 条件 2: 目标状态 v 必须完全可达 (可达性)
    U_init_test = pinv(R) * vec;
    err2 = norm(R * U_init_test - vec);
    
    % 如果满足代数条件 (容差 1e-5)
    if err1 < 1e-5 && err2 < 1e-5
        if abs(lam) >= 1
            % 找到了完美的不稳定极点！直接锁定并跳出循环
            valid_target_idx = idx;
            lambda = lam;
            v = vec;
            y_star = y_star_test;
            U_init = U_init_test;
            break;
        elseif fallback_idx == -1
            % 记录第一个(也就是模长最大、最接近1的)稳定的满足条件的极点
            fallback_idx = idx;
            fallback_lam = lam;
            fallback_v = vec;
            fallback_y_star = y_star_test;
            fallback_U_init = U_init_test;
        end
    end
end

% --- 决策与警告机制 ---
if valid_target_idx == -1
    if fallback_idx ~= -1
        % 启用降级攻击方案
        warning(['未找到不稳定的特征值 (|lambda| >= 1)。\n', ...
                 '系统已降级采用最接近 1 的稳定特征值 (lambda = %.4f)。\n', ...
                 '注意：此攻击下的误差将收敛至极限值而非趋于无穷大，但残差仍将被完美隐藏！'], fallback_lam);
        lambda = fallback_lam;
        v = fallback_v;
        y_star = fallback_y_star;
        U_init = fallback_U_init;
    else
        error('致命错误: 当前系统不存在任何满足“隐蔽性(Span)”和“可达性”的实数特征值！攻击在代数上不可行。');
    end
end

%% 2. 构造初始可达序列
m = size(Gamma, 2); 
U_matrix = reshape(U_init, m, n); 
y_init_seq = fliplr(U_matrix); 

%% 3. 计算缩放因子 scaling
delta_e = zeros(n, 1);
z_norms = zeros(n, 1);

for k = 1:n
    y_a = y_init_seq(:, k);
    delta_z = C * A * delta_e + Gamma * y_a;
    z_norms(k) = norm(delta_z);
    delta_e = A_cl * delta_e + B_att * y_a;
end

M = max(z_norms);
if M < 1e-12
    error('初始序列产生的残差接近0 (目标模态不可观测)，无法安全缩放。');
end
scaling = delta_z_max / M;

%% 4. 生成全局攻击序列 at_final
at_final = zeros(size(Gamma, 2), total_steps);

for k = 1:n
    at_final(:, k) = y_init_seq(:, k) * scaling;
end

for i = 0:(total_steps - n - 1)
    k_idx = n + i + 1;
    at_final(:, k_idx) = at_final(:, i + 1) - ( (lambda^(i+1) * scaling) * y_star );
end

%% 5. 构造带时间偏移的 Simulink 输入 (强化 ZOH)
attack_time_axis = (0:total_steps-1)' * Ts + start_time;

if start_time > 0
    full_time = [0; attack_time_axis]; 
    full_data = [zeros(size(Gamma, 2), 1), at_final];
else
    full_time = attack_time_axis;
    full_data = at_final;
end

simin = timeseries(full_data', full_time);
simin.Name = 'Attack_Signal';
simin.DataInfo.Interpolation = tsdata.interpolation('zoh');

%% 6. 统计输出
fprintf('--------------------------------------------------\n');
if valid_target_idx ~= -1
    fprintf('成功找到完美攻击特征值 (发散) lambda: %.4f\n', lambda);
else
    fprintf('成功部署降级攻击特征值 (收敛) lambda: %.4f\n', lambda);
end
fprintf('理论残差峰值: %.4f (实际已限幅为 %.4f)\n', M, delta_z_max);
fprintf('攻击开始时间: %.2f s\n', start_time);
fprintf('--------------------------------------------------\n');

end