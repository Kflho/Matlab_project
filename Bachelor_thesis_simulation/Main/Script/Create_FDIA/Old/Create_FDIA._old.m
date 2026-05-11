function simin=Create_FDIA(A,C)
%攻击序列
Garmma=[C;C*A;C*A*A;C*A*A*A];
at=[];
for i=1:10
garmma=rand(4,2);
at0=Garmma*garmma;
at=cat(1,at,at0);
end

%创建攻击序列
% 在MATLAB中定义数据
Ts = 1;  % 采样时间
sim_time = length(at) * Ts - Ts;  % 仿真时间

% 创建时间向量（每个时间点对应一个数据点）
time = (0:length(at)-1)' * Ts;

% 创建Simulink可识别的数据结构
% 方法A：使用时间序列
simin = timeseries(at', time);

% 在 Create_FDIA.m 脚本末尾添加
actual_attack_energy = sum(at(:).^2); % 计算生成的 at 序列的总能量
fprintf('当前生成的攻击总能量为: %.4f\n', actual_attack_energy);

