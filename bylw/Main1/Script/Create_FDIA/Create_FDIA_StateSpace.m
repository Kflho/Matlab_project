function [A_xi, C_xi, xi_0] = Create_FDIA_StateSpace(A, C, K, Gamma, delta_z_max)
% =========================================================================
% 功能：根据 FDIA 算法提取攻击参数，并构造对应的自治状态空间发生器
% 输入参数：与原序列生成脚本保持一致 (去掉了 total_steps 等时域参数)
% 输出参数：
%   A_xi : 攻击发生器的状态转移矩阵 (N_xi * N_xi)
%   C_xi : 攻击发生器的输出矩阵 (m * N_xi)
%   xi_0 : 攻击发生器的初始状态列向量 (N_xi * 1)
%          满足系统: xi(k+1) = A_xi * xi(k)
%                    y_a(k)  = C_xi * xi(k)
% =========================================================================

n = size(A, 1);
m = size(Gamma, 2);

%% 1. 筛选满足定理的特征值 (复用原逻辑)
[V, D] = eig(A);
eigenvalues = diag(D);

A_cl = A - K * C * A;
B_att = -K * Gamma;
R = [];
for i = 0:n-1
    R = [R, (A_cl^i) * B_att];
end

[~, sorted_indices] = sort(abs(eigenvalues), 'descend');
valid_target_idx = -1;
fallback_idx = -1;

for idx = sorted_indices'
    lam = eigenvalues(idx);
    vec = V(:, idx);
    
    if abs(imag(lam)) > 1e-6
        continue; 
    end
    lam = real(lam); vec = real(vec);
    
    y_star_test = pinv(Gamma) * (C * vec);
    err1 = norm(Gamma * y_star_test - C * vec);
    U_init_test = pinv(R) * vec;
    err2 = norm(R * U_init_test - vec);
    
    if err1 < 1e-5 && err2 < 1e-5
        if abs(lam) >= 1
            valid_target_idx = idx; lambda = lam; v = vec;
            y_star = y_star_test; U_init = U_init_test;
            break;
        elseif fallback_idx == -1
            fallback_idx = idx; fallback_lam = lam; fallback_v = vec;
            fallback_y_star = y_star_test; fallback_U_init = U_init_test;
        end
    end
end

if valid_target_idx == -1
    if fallback_idx ~= -1
        lambda = fallback_lam; v = fallback_v; 
        y_star = fallback_y_star; U_init = fallback_U_init;
        warning('采用稳定极点降级攻击: lambda = %.4f', lambda);
    else
        error('未找到可用特征值。');
    end
end

%% 2. 构造初始可达序列并计算安全缩放比 (复用原逻辑)
U_matrix = reshape(U_init, m, n); 
y_init_seq = fliplr(U_matrix); 

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
y_init_scaled = y_init_seq * scaling; % 缩放后的前 n 步攻击

%% 3. 构造自治状态空间矩阵 (核心创新点)
N_xi = n * m + 1; % 攻击状态发生器的维度
A_xi = zeros(N_xi, N_xi);

% (1) 填充移位寄存器部分 (y_a(k+1) -> y_a(k+2) 等)
for i = 1:(n-1)
    row_idx = (i-1)*m + 1 : i*m;
    col_idx = i*m + 1 : (i+1)*m;
    A_xi(row_idx, col_idx) = eye(m);
end

% (2) 填充递推差分方程行: y_a(k+n) = I*y_a(k) - (scaling*y_star) * lambda^k
row_idx = (n-1)*m + 1 : n*m;
A_xi(row_idx, 1:m) = eye(m);                     % 提取 y_a(k)
A_xi(row_idx, end) = -scaling * y_star;          % 耦合内部生成的 lambda^k

% (3) 填充指数生成器部分: lambda^(k+1) = lambda * lambda^k
A_xi(end, end) = lambda;

%% 4. 构造输出矩阵与初始状态
% 输出矩阵: 仅提取当前时刻的 y_a(k)，即状态向量的前 m 个元素
C_xi = zeros(m, N_xi);
C_xi(1:m, 1:m) = eye(m);

% 初始状态 xi_0 (相当于 k=1 的时刻)
xi_0 = zeros(N_xi, 1);
for i = 1:n
    xi_0( (i-1)*m + 1 : i*m ) = y_init_scaled(:, i);
end
xi_0(end) = lambda; % 指数项在 k=1 时的初始值为 lambda^1

%% 5. 打印信息
fprintf('--------------------------------------------------\n');
fprintf('攻击状态空间发生器构造成功！\n');
fprintf('目标系统维度 n: %d, 传感器维度 m: %d\n', n, m);
fprintf('攻击发生器状态维度 N_xi: %d\n', N_xi);
fprintf('可直接嵌入 LMI 增广矩阵中的 A_xi, C_xi 已生成。\n');
fprintf('--------------------------------------------------\n');

end