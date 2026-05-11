function simin = Create_FDIA(A, C, K, Gamma, delta_z_max, total_steps)
% Create_FDIA: 根据论文 Theorem 2 构造针对卡尔曼滤波器的虚假数据注入攻击序列
% A: 系统矩阵
% C: 测量矩阵
% K: 卡尔曼增益
% Gamma: 攻击注入矩阵
% delta_z_max: 用户定义的残差变化量上限变量
% total_steps: 期望生成的总仿真步数

n = size(A, 1); 

%% 1. 挑选最接近或超过 1 的特征值
[V, D] = eig(A);
eigenvalues = diag(D);
mags = abs(eigenvalues);

% 优先寻找不稳定特征值 (|lambda| >= 1)
unstable_indices = find(mags >= 1);

if ~isempty(unstable_indices)
    [~, local_idx] = max(mags(unstable_indices));
    target_idx = unstable_indices(local_idx);
    fprintf('状态: 检测到不稳定特征值，正在构造发散攻击。\n');
else
    [~, target_idx] = max(mags);
    fprintf('状态: 未检测到不稳定特征值，已选择最接近 1 的特征值构造隐蔽攻击。\n');
end

lambda = eigenvalues(target_idx);
v = V(:, target_idx); 

% 处理复数特征值（提取实部以生成实数信号）
if ~isreal(v) || ~isreal(lambda)
    v = real(v); 
    lambda = real(lambda);
    fprintf('注意: 特征值为复数，已提取其实部进行计算。\n');
end

%% 2. 求解转换向量 y_star (满足 Gamma * y_star = C * v)
y_star = pinv(Gamma) * (C * v);

%% 3. 构造初始可达序列 (引导误差状态至特征向量方向)
A_cl = A - K * C * A;
B_att = -K * Gamma;

% 构造可达性矩阵
R = [];
for i = 0:n-1
    R = [R, (A_cl^i) * B_att];
end

% 求解初始输入序列
U_init = pinv(R) * v;
y_init_seq = reshape(flipud(U_init), [], n); 

%% 4. 计算初始残差最大范数 M 并进行安全性缩放
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

%% 5. 生成完整攻击序列 (基于论文递归公式 34)
at_final = zeros(size(Gamma, 2), total_steps);

% 启动阶段 (前 n 步)
for k = 1:n
    at_final(:, k) = (y_init_seq(:, k)) * scaling;
end

% 维持/增长阶段 (从第 n 步开始)
for i = 0:(total_steps - n - 1)
    k_idx = n + i + 1;
    % 循环引用前 n 步的输入基准
    y_base = y_init_seq(:, mod(i, n) + 1);
    at_final(:, k_idx) = (y_base * scaling) - ( (lambda^(i+1) / M) * y_star * delta_z_max );
end

%% 6. 能量计算与输出 (新增功能)
% 计算生成的 at_final 序列的总能量
attack_energy = sum(at_final(:).^2); 

% 打印统计信息
fprintf('--------------------------------------------------\n');
fprintf('所选特征值 lambda: %.4f\n', lambda);
fprintf('设定残差阈值: %.4f\n', delta_z_max);
fprintf('当前生成的攻击总能量为: %.4f\n', attack_energy);
fprintf('--------------------------------------------------\n');

%% 7. 创建 Simulink 时间序列对象
Ts = 1;
time = (0:total_steps-1)' * Ts;
simin = timeseries(at_final, time);

end