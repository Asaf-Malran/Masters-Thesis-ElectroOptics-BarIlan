if exist('vid','var')
    delete(vid);
end
clc;close all; clearvars -except Controller E518 
%% pa6rameters
params.SC_material='Si 10um'; %'Si undoped';
params.target_r='1um'; % target
params.dis_SF=50; %NanoCube surface distance value
params.dis_FF=50; %NanoCube Current distance value
params.vorder='1'; % vortex order
params.freq_pump=10000; % Pump pluse repetion rate
params.pixel_size=3.45/50; % pixels size [um]
params.exposuretime=10000; %us
img_size=128; % image size ROI
params.ex_type='xy_Power';
%% scan parameters
ex_name='xy_scan_n_143';
params.power_measured=linspace(20,0,5)*1e-9;% Measured pump intensity with PD (nJ)
steps_x=-9:.05:9; %um
% steps_y= -2:0.5:2;%um
steps_y=zeros(1,15);%um

start_point=[50,50,params.dis_FF]; % NanoCube Start position
VEL = [1,1,1]*50; % NanoCube Velocity
params.steps_x=steps_x;
params.steps_y=steps_y;
params.steps_z=params.dis_FF;

params.start_point=start_point;
params.VEL=VEL; 

step_s=length(params.power_measured);
steps_n=length(steps_x)*length(steps_y)*step_s;

sampling=1; % number of sampling

% delay time
ODL_position=20; % mm Optical delay line position
params.ODL_position=ODL_position;
time_ps=2*ODL_position/3e8*1e9; %ps delay time between pump and probe
params.time_ps=time_ps;


%% variables
if exist(['results\',ex_name,'.mat'],'file')
    error('Error: the file already exists')
end
power_measured=params.power_measured*params.freq_pump*1000;
xx=linspace(-params.pixel_size*img_size/2,params.pixel_size*img_size/2,img_size);
position_mat=zeros(3,steps_n);
frame_mat=zeros(img_size,img_size,steps_n,sampling,'uint16');

%% camera setting
%prepare the camera to use
if ~exist('vid','var')
    vid = videoinput('gentl', 1, 'Mono12');
    
    src = getselectedsource(vid);
    src.ExposureTime=params.exposuretime; % exposure time in sec
    src.AcquisitionFrameRateEnable = 'True';
    src.AcquisitionFrameRate = 50;
    vid.ROIPosition = [650   425   512   512];
    start(vid); % start camera
    preview(vid);
end
%% NanoCube Connection
if(~exist('Controller','var'))
    Controller = PI_GCS_Controller();
    if(~isa(Controller,'PI_GCS_Controller'))
        Controller = PI_GCS_Controller();
    end
    devicesUsb = char(Controller.EnumerateUSB());
    disp(devicesUsb);
    E518 = Controller.ConnectUSB('119037638');
    disp([num2str(length(devicesUsb)), ' PI controllers are connected to your PC via USB']);
    % Start connection
    E518.qIDN() % query controller identification
    E518 = E518.InitializeController(); % initialize controller
    % Configuration and referencing
    availableaxes = E518.qSAI_ALL; % query controller axes
    if(isempty(availableaxes))
        error('No axes available');
    end   
    for i=1:3 % switch on servo and search reference switch to reference stage  
        E518.SVO(availableaxes{i}, 1); % Set Servo State (Open-Loop / Closed-Loop Operation)
    end
    E518.ONL(1, 1); %Sets control mode for piezo channel  
else
    availableaxes = E518.qSAI_ALL; % query controller axes
    if(isempty(availableaxes))
        error('No axes available');
    end
end
for jj=1:3
    E518.VCO(availableaxes{jj},1);
    E518.VEL(availableaxes{jj},VEL(jj));
    E518.MOV(availableaxes{jj}, start_point(jj));
end
%% calibration
disp('Move out of the targets and take background image:'); pause
frame_BG=getsnapshot(vid);
disp('turn on the laser and press enter (pump on)'); pause
frame=getsnapshot(vid);
[a,ccy]=max(frame);
[~,cc(1)]=max(a);
cc(2)=ccy(cc(1));
ROI=[cc-img_size/2,img_size-1,img_size-1];
%analysis
figure;imagesc(imcrop(frame-frame_BG,ROI))
frame_BG=imcrop(frame_BG,ROI);
%% run experiment
% E518.VEL(availableaxes{1}, 50);  % ציר Y – מהירות רגילה
% E518.VEL(availableaxes{2}, 5);   % ציר X – מהירות סריקה איטית
% E518.VEL(availableaxes{3}, 50);  % ציר Z – מהירות רגילה

%% user-defined scan speed (in um/sec)
scan_speed = 2;  % <== change this value to control scan speed
step_size = abs(steps_x(2) - steps_x(1));
pause_time = step_size / scan_speed;

count=0;
figure;
tic
disp('Move to the tragets and press enter');
for sind=1:step_s
    disp(['change pump intensity to: ',num2str(power_measured(sind)),'mW']); pause
    
    pause(1);
    for yind=1:length(steps_y)
        E518.MOV(availableaxes{1}, start_point(1)+steps_y(yind));
        pause(1);
        for xind=1:length(steps_x)           
            count=count+1;
            target_pos = start_point(2) + steps_x(xind);
            E518.MOV(availableaxes{2}, target_pos);
%             while abs(E518.qPOS(availableaxes{2}) - target_pos) > 0.01
%                 pause(0.001);
%             end
            pause(pause_time); % <-- control scan speed manually here
            position_mat(1,count)=E518.qPOS(availableaxes{1});
            position_mat(2,count)=E518.qPOS(availableaxes{2});
            position_mat(3,count)=E518.qPOS(availableaxes{3});
            for ss=1:sampling
                frame=getsnapshot(vid);
                frame_mat(:,:,count,ss)=imcrop(frame,ROI);
            end
            %disp(position_mat(:,count))
            
        end
        disp([' progress: ',...
            num2str(round(count/steps_n*100,1)),'%'])        
    end
    fs = 8000;                          % תדר דגימה
    t = 0:1/fs:0.2;                     % משך הצליל (0.2 שניות)
    f = 1000;                           % תדר הצליל (1000 הרץ)
    sound(sin(2*pi*f*t), fs);          % הפעלת הצליל
end




save(['results\',ex_name],'frame_mat','position_mat','frame_BG','ROI','params');

%% Close the connection
for jj=1:3
    E518.MOV(availableaxes{jj}, start_point(jj));
end
stop(vid);
delete(vid);
toc
disp('finish');
frame_mat=squeeze(mean(frame_mat,4));
target_scan_analysis_Power(frame_mat,params,25)


