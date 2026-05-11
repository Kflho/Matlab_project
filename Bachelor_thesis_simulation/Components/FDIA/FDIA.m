clc;

Ts = 1;  % 采样时间
sim_time = length(at) * Ts - Ts;  % 仿真时间

% 创建时间向量（每个时间点对应一个数据点）
time = (0:length(at)-1)' * Ts;

A=[0.975 0 0.042 0;0 0.977 0 0.044;0 0 0.958 0;0 0 0 0.956]
B=[0.0515 0.0016;0.0019 0.0447;0 0.0737;0.0850 0];
C=[0.2 0 0 0;0 0.2 0 0];

%攻击序列
Garmma=[C;C*A;C*A*A;C*A*A*A]
garmma=rand([4,2])
at0=Garmma*garmma
at=cat(1,[0 0;0 0;0 0;0 0;0 0],at0)

%极点配置
J=[-0.5 -0.4 0.4 0.5];
L=place(A',C',J)';



%创建攻击序列


% 创建Simulink可识别的数据结构
% 方法A：使用时间序列
simin = timeseries(at', time);
