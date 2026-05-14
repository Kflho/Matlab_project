% legend_setting.m
% 设置图例样式
% 调用方式：先 legend('曲线1','曲线2',...)，再 legend_setting;

hLegend = findobj(gcf, 'Type', 'Legend');
if ~isempty(hLegend)
    set(hLegend, 'FontName',  '宋体');      % 原来是 Arial
    set(hLegend, 'FontSize',   8);
    set(hLegend, 'Box',        'off');
    set(hLegend, 'Location',   'best');
end