clc;
%创建受控系统
[A,B,C,D,x_eq,u_eq]=Create_shoukong;
%创建FDIA序列
simin=Create_FDIA(A,B,C);
%创建噪声
[Vk,Wk]=Create_noise;
I_a=eye(length(A));
P0=diag([10;10;10;10]);



%状态观测器极点配置
J=[-0.5 -0.4 0.4 0.5];
L=place(A',C',J)';
%反馈控制矩阵
K=[3.0993 4.0721 -2.0528 2.8417;3.9353 3.3330 2.8461 -1.9997];



