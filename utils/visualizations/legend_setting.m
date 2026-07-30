% legend_setting.m
% 设置图例样式
% 调用方式：先 legend('曲线1','曲线2',...)，再 legend_setting;

hLegend = findobj(gcf, 'Type', 'Legend');
if ~isempty(hLegend)
    set(hLegend, 'FontName',  '宋体');
    set(hLegend, 'FontSize',   10);
    set(hLegend, 'Box',        'off');
    % Location 由各实验脚本自行设置，此处不覆盖
end