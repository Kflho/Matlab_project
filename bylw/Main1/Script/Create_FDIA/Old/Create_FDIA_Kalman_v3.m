function simin = Create_FDIA_Kalman_v3(A, C, K, Gamma, delta_z_max, total_steps, start_time, Ts)
% A, C, K, Gamma: 系统矩阵与卡尔曼增益
% delta_z_max: 残差阈值
% total_steps: 攻击序列本身的长度（步数）
% start_time: 攻击开始的物理时间（秒）
% Ts: 采样周期（秒），默认为 1

if nargin < 8, Ts = 1; end
if nargin < 7, start_time = 0; end

n = size(A, 1); 

%% 1. 挑选特征值与特征向量
[V, D] = eig(A);
eigenvalues = diag(D);
mags = abs(eigenvalues);

unstable_indices = find(mags >= 1);
if ~isempty(unstable_indices)
    [~, local_idx] = max(mags(unstable_indices));
    target_idx = unstable_indices(local_idx);
else
    [~, target_idx] = max(mags);
end

lambda = eigenvalues(target_idx);
v = V(:, target_idx); 

if ~isreal(v) || ~isreal(lambda)
    v = real(v); 
    lambda = real(lambda);
end

%% 2. 求解转换向量 y_star
y_star = pinv(Gamma) * (C * v);

%% 3. 构造初始可达序列
A_cl = A - K * C * A;
B_att = -K * Gamma;

R = [];
for i = 0:n-1
    R = [R, (A_cl^i) * B_att];
end

U_init = pinv(R) * v;
y_init_seq = reshape(flipud(U_init), [], n); 

%% 4. 计算缩放因子 scaling
delta_e = zeros(n, 1);
z_norms = zeros(n, 1);

for k = 1:n
    y_a = y_init_seq(:, k);
    delta_z = C * A * delta_e + Gamma * y_a;
    z_norms(k) = norm(delta_z);
    delta_e = A_cl * delta_e + B_att * y_a;
end

M = max(z_norms);
scaling = delta_z_max / M;

%% 5. 生成攻击序列 at_final
at_final = zeros(size(Gamma, 2), total_steps);

for k = 1:n
    at_final(:, k) = y_init_seq(:, k) * scaling;
end

for i = 0:(total_steps - n - 1)
    k_idx = n + i + 1;
    y_base = y_init_seq(:, mod(i, n) + 1);
    at_final(:, k_idx) = (y_base * scaling) - ( (lambda^(i+1) / M) * y_star * delta_z_max );
end

%% 6. 构造带时间偏移的 Simulink 输入 (核心修改点)
% 计算攻击开始后的时间点
attack_time_axis = (0:total_steps-1)' * Ts + start_time;

if start_time > 0
    % 在 t=0 时刻注入 0，并在攻击开始前保持 0
    % 构造：[0, start_time, 攻击时间点...]
    % 对应的信号为：[0, 0, 攻击数据...]
    full_time = [0; start_time - 1e-9; attack_time_axis]; % 减去 1e-9 是为了确保在 start_time 阶跃进入
    full_data = [zeros(size(Gamma, 2), 2), at_final];
else
    full_time = attack_time_axis;
    full_data = at_final;
end

% 生成 timeseries 对象
simin = timeseries(full_data, full_time);
simin.Name = 'Attack_Signal';

%% 7. 统计输出
attack_energy = sum(at_final(:).^2); 
fprintf('--------------------------------------------------\n');
fprintf('所选特征值 lambda: %.4f\n', lambda);
fprintf('攻击开始时间: %.2f s (Ts = %.2f)\n', start_time, Ts);
fprintf('设定残差阈值: %.4e\n', delta_z_max);
fprintf('攻击部分总能量: %.4e\n', attack_energy); 
fprintf('--------------------------------------------------\n');

end