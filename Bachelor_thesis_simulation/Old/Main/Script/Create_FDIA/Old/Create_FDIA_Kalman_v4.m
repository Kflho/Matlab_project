function simin = Create_FDIA_Kalman_v4(A, C, K, Gamma, delta_z_max, total_steps, start_time, Ts)
% A, C, K, Gamma: 系统矩阵与卡尔曼增益
% delta_z_max: 残差阈值
% total_steps: 攻击序列本身的长度（步数）
% start_time: 攻击开始的物理时间（秒）
% Ts: 采样周期（秒），默认为 1

if nargin < 8, Ts = 1; end
if nargin < 7, start_time = 0; end

n = size(A, 1); 

%% 1. 挑选特征值与特征向量 (修复复数处理逻辑)
[V, D] = eig(A);
eigenvalues = diag(D);

% 寻找模大于1且虚部极小（实数）的特征值
real_unstable_indices = find(abs(eigenvalues) >= 1 & abs(imag(eigenvalues)) < 1e-6);

if ~isempty(real_unstable_indices)
    [~, local_idx] = max(abs(eigenvalues(real_unstable_indices)));
    target_idx = real_unstable_indices(local_idx);
else
    % 如果没有实数不稳定极点，降级为取最大的特征值并抛出警告
    warning('未找到实数且不稳定的特征值。使用最大模长特征值的实部，可能导致残差无法完美抵消！');
    [~, target_idx] = max(abs(eigenvalues));
end

lambda = real(eigenvalues(target_idx));
v = real(V(:, target_idx)); 

%% 2. 求解转换向量 y_star
y_star = pinv(Gamma) * (C * v);

%% 3. 构造初始可达序列 (修复矩阵重组错位问题)
A_cl = A - K * C * A;
B_att = -K * Gamma;

R = [];
for i = 0:n-1
    R = [R, (A_cl^i) * B_att];
end

U_init = pinv(R) * v;

% 【修正】先重组为矩阵，再按列翻转，防止多通道数据上下错乱
m = size(Gamma, 2); % 攻击通道数
U_matrix = reshape(U_init, m, n); 
y_init_seq = fliplr(U_matrix); 

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

%% 5. 生成攻击序列 at_final (修复全局递归逻辑)
at_final = zeros(size(Gamma, 2), total_steps);

% 阶段 1：初始侵入期
for k = 1:n
    at_final(:, k) = y_init_seq(:, k) * scaling;
end

% 阶段 2：指数破坏期
for i = 0:(total_steps - n - 1)
    k_idx = n + i + 1;
    % 【修正】严格按照公式 U_{n+i} = U_{i} - lambda^(i+1) * c * y* 进行递归累减
    at_final(:, k_idx) = at_final(:, i + 1) - ( (lambda^(i+1) * scaling) * y_star );
end

%% 6. 构造带时间偏移的 Simulink 输入 (修复数据转置问题)
attack_time_axis = (0:total_steps-1)' * Ts + start_time;

if start_time > 0
    full_time = [0; start_time - 1e-9; attack_time_axis]; 
    full_data = [zeros(size(Gamma, 2), 2), at_final];
else
    full_time = attack_time_axis;
    full_data = at_final;
end

% 【修正】转置 full_data，确保传入 timeseries 时，行是时间，列是通道信号
simin = timeseries(full_data', full_time);
simin.Name = 'Attack_Signal';

%% 7. 统计输出
attack_energy = sum(at_final(:).^2); 
fprintf('--------------------------------------------------\n');
fprintf('所选特征值 lambda: %.4f\n', lambda);
fprintf('攻击开始时间: %.2f s (Ts = %.2f)\n', start_time, Ts);
fprintf('设定残差阈值: %.4e\n', delta_z_max);
fprintf('原始残差峰值 M: %.4f, 缩放比 c: %.4f\n', M, scaling);
fprintf('攻击部分总能量: %.4e\n', attack_energy); 
fprintf('--------------------------------------------------\n');

end