function simin = Create_FDIA_Kalman_v2(A, C, K, Gamma, delta_z_max, total_steps)
% 不需要 Symbolic Math Toolbox 的高兼容性版本
% 使用标准 double 精度计算，并通过科学计数法解决极小值显示问题

n = size(A, 1); 

%% 1. 挑选特征值与特征向量
[V, D] = eig(A);
eigenvalues = diag(D);
mags = abs(eigenvalues);

% 优先寻找不稳定特征值 (|lambda| >= 1)，否则选最接近 1 的
unstable_indices = find(mags >= 1);
if ~isempty(unstable_indices)
    [~, local_idx] = max(mags(unstable_indices));
    target_idx = unstable_indices(local_idx);
    fprintf('状态: 检测到不稳定特征值。\n');
else
    [~, target_idx] = max(mags);
    fprintf('状态: 未检测到不稳定特征值，选择最接近 1 的特征值。\n');
end

lambda = eigenvalues(target_idx);
v = V(:, target_idx); 

% 处理复数：提取实部
if ~isreal(v) || ~isreal(lambda)
    v = real(v); 
    lambda = real(lambda);
end

%% 2. 求解转换向量 y_star (满足 Gamma * y_star = C * v)
y_star = pinv(Gamma) * (C * v);

%% 3. 构造初始可达序列
A_cl = A - K * C * A;
B_att = -K * Gamma;

% 构造可达性矩阵 R = [B, AB, ..., A^(n-1)B]
R = [];
for i = 0:n-1
    R = [R, (A_cl^i) * B_att];
end

% 求解初始输入序列 (对应论文第 4.1 节)
U_init = pinv(R) * v;
y_init_seq = reshape(flipud(U_init), [], n); 

%% 4. 计算初始残差最大范数 M 并进行缩放
delta_e = zeros(n, 1);
z_norms = zeros(n, 1);

for k = 1:n
    y_a = y_init_seq(:, k);
    % 残差变化量 delta_z_k+1 = CA*delta_e + Gamma*y_a_k+1
    delta_z = C * A * delta_e + Gamma * y_a;
    z_norms(k) = norm(delta_z);
    delta_e = A_cl * delta_e + B_att * y_a;
end

M = max(z_norms);
% 缩放因子：确保残差在阈值 delta_z_max 之内
scaling = delta_z_max / M;

%% 5. 生成完整攻击序列 (基于论文公式 34)
at_final = zeros(size(Gamma, 2), total_steps);

% 启动阶段 (前 n 步)
for k = 1:n
    at_final(:, k) = y_init_seq(:, k) * scaling;
end

% 维持/增长阶段 (第 n 步之后)
for i = 0:(total_steps - n - 1)
    k_idx = n + i + 1;
    y_base = y_init_seq(:, mod(i, n) + 1);
    % 公式: y_{n+i}^a = (delta/M) * (y_i^a - lambda^(i+1) * y^*)
    at_final(:, k_idx) = (y_base * scaling) - ( (lambda^(i+1) / M) * y_star * delta_z_max );
end

%% 6. 能量计算与统计输出 (优化显示格式)
% 使用 double 精度计算总能量
attack_energy = sum(at_final(:).^2); 

fprintf('--------------------------------------------------\n');
fprintf('所选特征值 lambda: %.4f\n', lambda);
% 使用 %e 科学计数法显示，即使数值极小也不会显示为 0.0000
fprintf('设定残差阈值: %.4e\n', delta_z_max);
fprintf('当前生成的攻击总能量为: %.4e\n', attack_energy); 
fprintf('--------------------------------------------------\n');

%% 7. 输出为 Simulink 格式
Ts = 1;
time = (0:total_steps-1)' * Ts;
simin = timeseries(at_final, time);

end