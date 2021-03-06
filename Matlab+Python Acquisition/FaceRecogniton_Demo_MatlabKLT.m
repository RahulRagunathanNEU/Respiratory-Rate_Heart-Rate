%camera initialization--blackfly using matlab

%% FACE RECOGNITION DEMO

%% Trying to support MULTIPLE ROIS
close all
clear all
clc

imaqreset % clear config and stops camera
%% flags
face_det_flag=1; % 1 if we use open CV to locate face, 0 if we want to manually choose ROI
MLSVD_FilterXY_Flag=0; % Filtering images in X and Y using MLSVD
% analysis flags
MLSVD_Analysis_Flag=0; % 1 if we are we analyzing using MLSVD
EMD_Analysis_Flag=1; %  1 if we are analyzing using EMD methods

%% Bounding box and Filter ranges
bp_mat{1}=[0.7 3.5];bp_mat{2}=[0.1 0.8]; % PER BOUNDING BOX
imf_mat{1}=[2 NaN];imf_mat{2}=[1 NaN]; % NaNs mean use the last component of IMF
num_ROIs=2; % How many ROIs are we analyzing
sf_arr=[1.1 1.1]; % blackfly, ST01 Setting
mn_arr=[3 3];


sf_bf=sf_arr(1); % blck fly
mn_bf=mn_arr(1);

sf_ST=sf_arr(2); % st01
mn_ST=mn_arr(2);
%% Parameters we fix for analysis
%fs_est=15; % what fs we want, frames per scond
%Analysis_Window_Length=7; % in seconds

%% other settings relatd to camera
exp_time=120;%66.6667;%(1/fs_est)*1000; % exposure time in ms
%
init_tc_frame_count=0;% how many frames will we throw away..  round(Init_tc/(1/fs_est));
%Analysis_frame_count=225;%round(Analysis_time/(1/fs_est));% converts time to frames as an estimate-- Rounds to whole number of frames
%Refresh_frame_count=25;% Analysis_frame_count;%round(Refresh_time/(1/fs_est)); % coverts time to frames as an estimate-- Rounds to whole number of frames
%time_d=0.1; % delay between images

%% INITIALIZING IR SOURCE IF STRUCTURE SENSOR
%% adding relevant paths
modpath='./Python Functions';
matlabfun_path='./Matlab Functions';
addpath(genpath(modpath));
addpath(genpath(matlabfun_path));
% reload python modules


%
%% Initialization-- Turns on video streams
dlib_key=imread('dlib_68pt_mapping_key.png'); % where the 68 landmark points SHOULD BE
VideoStreams=Camera_Initialization(modpath); % initialize
py.CameraFunctions.kill_both_streams(VideoStreams) % kill
pause(1)
VideoStreams=Camera_Initialization(modpath); % initialize
%% initializing Blackfly camera
tStart=tic;

%temp_cam_info       = imaqhwinfo('mwspinnakerimaq'); % Find info about system devices
%camList    = {temp_cam_info.DeviceInfo.DeviceName}; % Create list of available video devices
%camera.cam = videoinput('winvideo',1,char(temp_cam_info.DeviceInfo(1).SupportedFormats(9))); % 9 is RGB24_960x540,10 default for YUY2 720x1280--Internal Webcam asus
%camera.cam = videoinput('mwspinnakerimaq',1,char(temp_cam_info.DeviceInfo(1).SupportedFormats(3))); % 9 is RGB24_960x540,10 default for YUY2 720x1280--Internal Webcam asus
disp("Blackfly")


%camera.cam.FramesPerTrigger=1; % 1 frame per trigger
%camprop = getselectedsource(camera.cam);
disp("Set camera properties")
vid = videoinput('mwspinnakerimaq', 1, 'Mono16'); % mono16 image

src = getselectedsource(vid);

% preview(vid);
%
% stoppreview(vid);
%
src.ExposureTime = round(exp_time*1000);
%
% preview(vid);
%
% stoppreview(vid);
% closepreview

src.GainConversion = 'HCG'; % high conversion gain-- better for low light imaging
src.AdcBitDepth = 'Bit12'; % 12 bit ADC bit depth
vid.ROIPosition = [0 0 1936 1464]; % crop in matlab-- we always look at full image in matlab
%src.AcquisitionFrameCount=1;
%src.ExposureTime = round(exp_time*1000);

triggerconfig(vid, 'manual'); % manual trigger
vid.TriggerRepeat = Inf;
%% Taking specified images USING BLACKFLY
cam_init_flag=0; % initializ camera first

dim1=320; % currently fixed for camera
dim2=240; % currently fixed for camera
% plotting images from both sensors;


image_struct_first=BlackFly_TakeImgv2(vid,1,cam_init_flag); % BLACKFLY

%% RESIZING IMAGE+ Transposes
orig=image_struct_first.images;
scale=0.4; % resize scale
temp=imresize(orig,scale);
%% END RESIZING IMAGE
image_struct_first.images=temp; % flip image

%image_struct_ST01=Take_Images_Fixedv2(VideoStreams,1,0,dim1,dim2);
cam_init_flag=1; % now it is initialized
%image_struct_first=BlackFly_TakeImg(vid,Analysis_frame_count+init_tc_frame_count);

nrows=1;
ncols=1;
figure;
ax1=subplot(nrows,ncols,1);im1=imagesc(image_struct_first.images(:,:,1));colorbar
title("BlackFly")
hold on
%ax2=subplot(nrows,ncols,2);im2=imagesc(image_struct_ST01.images(:,:,1));colorbar
%title("Structure Sensor Image")
%hold on
%[Cascade_outputs]=py.CameraFunctions.set_predictor_cascade; % preload classifiers to save time ONCE

if face_det_flag==1 % use facedetector
    faceDetector = vision.CascadeObjectDetector('ScaleFactor',1.1); % initializing
    img_ctr=1;
    while(1)
        
        
        if exist('landmarks')&&exist('rectangles')
            
             delete(landmarks)
           delete(rectangles)
           %clear(landmarks)
           %clear(rectangles)
           clear rectangles landmarks
           
        end
        image_struct_first=BlackFly_TakeImgv2(vid,1,cam_init_flag); % BLACKFLY
        % Transposing and flipping
        orig=image_struct_first.images;
        temp=imresize(orig,scale);
        image_struct_first.images=temp; %
        
        %% Matlab computer vision toolbox
        if img_ctr==1
            BBox_bf=step(faceDetector,image_struct_first.images);
            points = detectMinEigenFeatures(image_struct_first.images, 'ROI',BBox_bf);  % Landmarks to follow
            visiblePoints=points;
            %% USE KLT TO TRACK
            pointTracker = vision.PointTracker('BlockSize',[51 51],'NumPyramidLevels',4);
            
            % Initialize the tracker with the initial point locations and the initial
            % video frame.
            points = points.Location;
            initialize(pointTracker, points, image_struct_first.images);
            bboxPoints = bbox2points(BBox_bf(1, :));
            
            BBox_bf2=[min(bboxPoints(:,1)), min(bboxPoints(:,2)),max(bboxPoints(:,1))-min(bboxPoints(:,1)),max(bboxPoints(:,2))-min(bboxPoints(:,2))],
            
        end
        oldPoints=points; % old points 
        
        
        
        if img_ctr==0  % not the first frame
           [points, isFound] = step(pointTracker, image_struct_first.images); 
            visiblePoints = points(isFound, :);
            oldInliers = oldPoints(isFound, :);
            
            
            % Estimate the geometric transformation between the old points
        % and the new points and eliminate outliers
        
         if size(visiblePoints, 1) >= 2 % need at least 2 points
        [xform, inlierIdx] = estimateGeometricTransform2D(...
            oldInliers, visiblePoints, 'similarity', 'MaxDistance', 4);
        oldInliers    = oldInliers(inlierIdx, :);
        visiblePoints = visiblePoints(inlierIdx, :);
        
        % Apply the transformation to the bounding box points
        bboxPoints = transformPointsForward(xform, bboxPoints);
                
        % Insert a bounding box around the object being tracked
        bboxPolygon = reshape(bboxPoints', 1, []);
        BBox_bf2=[min(bboxPoints(:,1)), min(bboxPoints(:,2)),max(bboxPoints(:,1))-min(bboxPoints(:,1)),max(bboxPoints(:,2))-min(bboxPoints(:,2))];
        
        
        % Reset the points
        oldPoints = visiblePoints;
        setPoints(pointTracker, oldPoints);    
        
            
         end
            
            
        end
        
        
        
        % plot 
        %set(im1,'CData',image_struct_first.images)
        imagesc(image_struct_first.images);colorbar;hold on
        if size(BBox_bf,1)==1
           %rectangles=rectangle(ax1,'Position',BBox_bf2); % Face 
           rectangle(ax1,'Position',BBox_bf2,'LineWidth',4);
           if img_ctr==1
           %landmarks=scatter(ax1,visiblePoints.Location(:,1),visiblePoints.Location(:,2),'ro'); % landmarks
           scatter(visiblePoints.Location(:,1),visiblePoints.Location(:,2),'ro'); % landmarks
           end
           
           if img_ctr==0
           %landmarks=scatter(ax1,visiblePoints(:,1),visiblePoints(:,2),'ro'); % landmarks
           scatter(visiblePoints(:,1),visiblePoints(:,2),'ro'); % landmarks
           end
           
           drawnow
          
           
        end
        
        
        
       
        %        end
        pause(0.1);
        img_ctr=0;
    end
    
    
end
