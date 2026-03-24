clc;
% close all;
clearvars -except Controller E518 nit

% --- הגדרת משתנים ---
d_ROI_um=0.8;
ex=72;
load(['results\xy_scan_n_',num2str(ex),'.mat']); 

% --- עיבוד נתונים ראשוני ---
frame_mat=squeeze(mean(frame_mat-frame_BG,4));
%%
img_size=size(frame_mat,[1 2]);
px_size=params.pixel_size;
d_ROI=d_ROI_um/px_size;
y=params.steps_y;
x=params.steps_x;
z=params.steps_z;
PP=params.power_measured*1e9;
sind=length(x)*length(y);
[X_grid,Y_grid] = meshgrid(1:size(frame_mat,1),1:size(frame_mat,2)); % הגדרת הגריד

% -------------------------------------------------------------
% --- הגדרת הצבעים בדיוק לפי התמונה שלך ---
% -------------------------------------------------------------
% הסדר: כחול, אדום, ירוק, צהוב, שחור
fixed_colors = [
    0, 0, 1;    % Blue
    1, 0, 0;    % Red
    0, 0.8, 0;  % Green (טיפה כהה יותר כדי שיראו טוב על לבן, כמו בתמונה)
    0.9, 0.9, 0;% Yellow (כהה מעט כדי שיהיה קריא)
    0, 0, 0     % Black
];

% --- הגדרת Figure לגרף הראשי ---
h=figure('Position',[401.8000 343 1.0928e+03 420]);
hold on;
title('Super-Resolution Imaging: Probe Transmission Profile for 500 nm Target (Pump On vs. Pump Off)'); 
xlabel('x [\mum]'); 
ylabel('Transmission [a.u.]');

% -------------------------------------------------------------
% --- לולאת עיבוד ושרטוט ---
% -------------------------------------------------------------
for ii = 1%:length(PP)
    
    % בחירת צבע מתוך הרשימה הקבועה (באופן מחזורי אם יש יותר מ-5 עוצמות)
    color_idx = mod(ii-1, size(fixed_colors,1)) + 1;
    current_color = fixed_colors(color_idx, :);
    
    mm_image=double(frame_mat(:,:,(1:sind)+sind*(ii-1)));
    std_img=std(mm_image,[],3);
    
    % --- איתור מרכז ה-ROI (אם לא קיים) ---
    if ~exist('cc','var')
        [a,ind1]=max(std_img);
        [~,ind2]=max(a);
        ind1=ind1(ind2);
        cc=[ind1,ind2];
    end
    
    % --- יצירת תמונת ROI ---
    figure;
    dim=[cc(2)+round(-d_ROI/2),cc(1)+round(-d_ROI/2),...
        d_ROI,d_ROI];
    xy=linspace(-px_size*img_size(1)/2,px_size*img_size(1)/2,img_size(1));
    imagesc(xy,xy,std_img); axis image
    rectangle('Position',[xy(dim([1,2])),px_size*d_ROI*[1,1]],'EdgeColor','r','Curvature',[1 1])
    
    
    % --- יצירת וקטור ה-Scan Max ---
    ROI_circ=(X_grid-cc(2)).^2+(Y_grid-cc(1)).^2<(d_ROI/2)^2; 
    ROI_images=mm_image.*ROI_circ; 
    max_map=reshape(squeeze(max(max(mm_image))),length(x),length(y));
    
    max_vec=squeeze(mean(max_map,2));
    max_vec_normalized = max_vec/max(max_vec); % Normalization
    
    % --- שרטוט הגרף הדו-ממדי (Scan max map) ---
    figure; 
    imagesc(x,y,max_map'/max(max_vec)); axis image
    xlabel('x [\mum]'); ylabel('y [\mum]');
    sgtitle(['Pulse power: ',num2str(PP(ii)),...
        'nJ,  Z: ',num2str(z),'\mum']);
    
    
    % --- שרטוט הגרף הראשי (Scan max profile) ---
    figure(h.double);
    
    % כאן אנו משתמשים בצבע שקבענו למעלה (current_color)
    plot(x,max_vec_normalized,...
        'DisplayName',['PP: ',num2str(PP(ii)),'nJ'],...
        'Color', current_color);  % <--- השינוי הקריטי
    
    
%     % -------------------------------------------------------------------
%     % --- איתור וסימון נקודות יעד ספציפיות ליד האפס ---
%     % -------------------------------------------------------------------
% 
%     % רק אם זה קו ה-Pump On (ii=1) נבצע את האיתור והסימון
%     if ii == 1 
%         % 1. הגדרת טווח החיפוש הצר: x בין -2 ל-2 
%         search_range_indices = find(x >= -2 & x <= 2);
% 
%         if ~isempty(search_range_indices)
% 
%             central_data = max_vec_normalized(search_range_indices);
%             central_x = x(search_range_indices);
% 
%             % 2. מציאת מקסימום ומינימום מקומיים
%             [max_vals, peak_locs] = findpeaks(central_data, 'MinPeakProminence', 0.015, 'NPeaks', 5); 
%             [min_vals, valley_locs] = findpeaks(-central_data, 'MinPeakProminence', 0.015, 'NPeaks', 5);
% 
% 
%             if ~isempty(peak_locs) && ~isempty(valley_locs)
% 
%                 % 3. *** איתור מינימום ב-X=0.35 ומקסימום ב-X=0.85 ***
%                 X_valleys = central_x(valley_locs);
%                 Y_valleys = -min_vals;
%                 X_peaks = central_x(peak_locs);
%                 Y_peaks = max_vals;
%                 % א. מציאת המינימום (Valley) שהכי קרוב ל-X=0.35
%                 [~, idx_min_target] = min(abs(X_valleys - 0.35)); 
%                 X_min_target = X_valleys(idx_min_target);
%                 Y_min_target = Y_valleys(idx_min_target);
% 
%                 % ב. מציאת המקסימום (Peak) שהכי קרוב ל-X=0.85
%                 [~, idx_max_target] = min(abs(X_peaks - 0.85));
%                 X_max_target = X_peaks(idx_max_target);
%                 Y_max_target = Y_peaks(idx_max_target);
% 
% 
%                 % --- סימון הנקודות בגרף (X אדום) ---
% 
%                 % 1. סמן עבור המקסימום המקומי (Peak)
%                 plot(X_max_target, Y_max_target, 'rx', 'MarkerSize', 8, 'Color', [1 0 0], 'LineWidth', 2);
% 
%                 % 2. סמן עבור המינימום המקומי (Valley)
%                 plot(X_min_target, Y_min_target, 'rx', 'MarkerSize', 8, 'Color', [1 0 0], 'LineWidth', 2);
% 
%                 % 3. כיתוב המקסימום המקומי
%                 text_max_label = sprintf('Max: X:%.2f, Y:%.3f', X_max_target, Y_max_target);
%                 text(X_max_target - 0.1, Y_max_target + 0.015, text_max_label, ... 
%                      'HorizontalAlignment', 'right', 'Color', [1 0 0], 'FontSize', 9);
% 
%                 % 4. כיתוב המינימום המקומי
%                 text_min_label = sprintf('Min: X:%.2f, Y:%.3f', X_min_target, Y_min_target);
%                 text(X_min_target + 0.1, Y_min_target - 0.015, text_min_label, ... 
%                      'HorizontalAlignment', 'left', 'Color', [1 0 0], 'FontSize', 9);
% 
%             else
%                  disp(['Power: ', num2str(PP(ii)), ' nJ - Warning: No clear local extrema found near x=0.']);
%             end
%         end
%     end
% 
    % legend('Location','eastoutside');
end