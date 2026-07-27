
function out=start_simulink(model_name)
% === 新增：自动化运行 Simulink ===
disp('正在启动 Simulink 仿真...');
% 运行仿真，并将结果直接存入工作区（对应你模型中 To Workspace 模块的设置）
out=sim(model_name); 
disp('仿真完成，开始计算与绘图...');
close all;
% === 后面是你原有的计算和画图代码 ===