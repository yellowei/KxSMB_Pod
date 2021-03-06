//
//  FileViewController.m
//  KxSMB_Pod
//
//  Created by lzh on 2017/5/20.
//  Copyright © 2017年 harddog. All rights reserved.
//

#import "FileViewController.h"
#import "KxSMBProvider.h"
#import <QuickLook/QuickLook.h>

@interface FileViewController () <QLPreviewControllerDelegate, QLPreviewControllerDataSource>
@end

@implementation FileViewController {
    
    UIView          *_container;
    UILabel         *_nameLabel;
    UILabel         *_sizeLabel;
    UILabel         *_modifiedLabel;
    UILabel         *_createdLabel;
    UIButton        *_downloadButton;
    UIProgressView  *_downloadProgress;
    UILabel         *_downloadLabel;
    NSString        *_filePath;
    NSFileHandle    *_fileHandle;
    long            _downloadedBytes;
    NSDate          *_timestamp;
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
    }
    return self;
}

- (void) dealloc
{
    [self closeFiles];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    const CGSize size = self.view.bounds.size;
    const CGFloat W = size.width;
    
    _container = [[UIView alloc] initWithFrame:(CGRect){0,0,size}];
    _container.autoresizingMask = UIViewAutoresizingNone;
    _container.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_container];
    
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, W - 20, 25)];
    _nameLabel.font = [UIFont boldSystemFontOfSize:16];
    _nameLabel.textColor = [UIColor darkTextColor];
    _nameLabel.opaque = NO;
    _nameLabel.backgroundColor = [UIColor clearColor];
    _nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    _sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 35, W - 20, 25)];
    _sizeLabel.font = [UIFont systemFontOfSize:14];
    _sizeLabel.textColor = [UIColor darkTextColor];
    _sizeLabel.opaque = NO;
    _sizeLabel.backgroundColor = [UIColor clearColor];
    _sizeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    _modifiedLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 60, W - 20, 25)];
    _modifiedLabel.font = [UIFont systemFontOfSize:14];;
    _modifiedLabel.textColor = [UIColor darkTextColor];
    _modifiedLabel.opaque = NO;
    _modifiedLabel.backgroundColor = [UIColor clearColor];
    _modifiedLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    _createdLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, W - 20, 25)];
    _createdLabel.font = [UIFont systemFontOfSize:14];;
    _createdLabel.textColor = [UIColor darkTextColor];
    _createdLabel.opaque = NO;
    _createdLabel.backgroundColor = [UIColor clearColor];
    _createdLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    _downloadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _downloadButton.frame = CGRectMake(10, 120, 100, 30);
    _downloadButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_downloadButton setTitle:@"Download" forState:UIControlStateNormal];
    [_downloadButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [_downloadButton addTarget:self action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
    
    _downloadLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 150, W - 20, 40)];
    _downloadLabel.font = [UIFont systemFontOfSize:14];;
    _downloadLabel.textColor = [UIColor darkTextColor];
    _downloadLabel.opaque = NO;
    _downloadLabel.backgroundColor = [UIColor clearColor];
    _downloadLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _downloadLabel.numberOfLines = 2;
    
    _downloadProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _downloadProgress.frame = CGRectMake(10, 190, W - 20, 30);
    _downloadProgress.hidden = YES;
    
    [_container addSubview:_nameLabel];
    [_container addSubview:_sizeLabel];
    [_container addSubview:_modifiedLabel];
    [_container addSubview:_createdLabel];
    [_container addSubview:_downloadButton];
    [_container addSubview:_downloadLabel];
    [_container addSubview:_downloadProgress];
}

- (void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    const CGSize size = self.view.bounds.size;
    const CGFloat top = [self.topLayoutGuide length];
    _container.frame = (CGRect){0, top, size.width, size.height - top};
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _nameLabel.text = _smbFile.path;
    _sizeLabel.text = [NSString stringWithFormat:@"size: %lld", _smbFile.stat.size];
    _modifiedLabel.text = [NSString stringWithFormat:@"modified: %@", _smbFile.stat.lastModified];
    _createdLabel.text = [NSString stringWithFormat:@"created: %@", _smbFile.stat.creationTime];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //[self closeFiles];
}

- (void) closeFiles
{
    if (_fileHandle) {
        
        [_fileHandle closeFile];
        _fileHandle = nil;
    }
    
    [_smbFile close];
}

- (void) downloadAction
{
    if (!_fileHandle) {
        
        NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                NSUserDomainMask,
                                                                YES) lastObject];
        NSString *filename = _smbFile.path.lastPathComponent;
        _filePath = [folder stringByAppendingPathComponent:filename];
        
        NSFileManager *fm = [[NSFileManager alloc] init];
        if ([fm fileExistsAtPath:_filePath])
            [fm removeItemAtPath:_filePath error:nil];
        [fm createFileAtPath:_filePath contents:nil attributes:nil];
        
        NSError *error;
        _fileHandle = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:_filePath]
                                                        error:&error];
        
        if (_fileHandle) {
            
            [_downloadButton setTitle:@"Cancel" forState:UIControlStateNormal];
            _downloadLabel.text = @"starting ..";
            
            _downloadedBytes = 0;
            _downloadProgress.progress = 0;
            _downloadProgress.hidden = NO;
            _timestamp = [NSDate date];
            
            [self download];
            
        } else {
            
            _downloadLabel.text = [NSString stringWithFormat:@"failed: %@", error.localizedDescription];
        }
        
    } else {
        
        [_downloadButton setTitle:@"Download" forState:UIControlStateNormal];
        _downloadLabel.text = @"cancelled";
        [self closeFiles];
    }
}

-(void) updateDownloadStatus: (id) result
{
    if ([result isKindOfClass:[NSError class]]) {
        
        NSError *error = result;
        
        [_downloadButton setTitle:@"Download" forState:UIControlStateNormal];
        _downloadLabel.text = [NSString stringWithFormat:@"failed: %@", error.localizedDescription];
        _downloadProgress.hidden = YES;
        [self closeFiles];
        
    } else if ([result isKindOfClass:[NSData class]]) {
        
        NSData *data = result;
        
        if (data.length == 0) {
            
            [_downloadButton setTitle:@"Download" forState:UIControlStateNormal];
            [self closeFiles];
            
        } else {
            
            NSTimeInterval time = -[_timestamp timeIntervalSinceNow];
            
            _downloadedBytes += data.length;
            _downloadProgress.progress = (float)_downloadedBytes / (float)_smbFile.stat.size;
            
            CGFloat value;
            NSString *unit;
            
            if (_downloadedBytes < 1024) {
                
                value = _downloadedBytes;
                unit = @"B";
                
            } else if (_downloadedBytes < 1048576) {
                
                value = _downloadedBytes / 1024.f;
                unit = @"KB";
                
            } else {
                
                value = _downloadedBytes / 1048576.f;
                unit = @"MB";
            }
            
            _downloadLabel.text = [NSString stringWithFormat:@"downloaded %.1f%@ (%.1f%%) %.2f%@s",
                                   value, unit,
                                   _downloadProgress.progress * 100.f,
                                   value / time, unit];
            
            if (_fileHandle) {
                
                [_fileHandle writeData:data];
                
                if(_downloadedBytes == _smbFile.stat.size) {
                    
                    [self closeFiles];
                    
                    [_downloadButton setTitle:@"Done" forState:UIControlStateNormal];
                    _downloadButton.enabled = NO;
                    
                    if ([QLPreviewController canPreviewItem:[NSURL fileURLWithPath:_filePath]]) {
                        
                        QLPreviewController *vc = [QLPreviewController new];
                        vc.delegate = self;
                        vc.dataSource = self;
                        [self.navigationController pushViewController:vc animated:YES];
                    }
                    
                } else {
                    
                    [self download];
                }
            }
        }
    } else {
        
        NSAssert(false, @"bugcheck");
    }
}

- (void) download
{
    __weak __typeof(self) weakSelf = self;
    [_smbFile readDataOfLength:1024*1024
                         block:^(id result)
     {
         FileViewController *p = weakSelf;
         //if (p && p.isViewLoaded && p.view.window) {
         if (p) {
             [p updateDownloadStatus:result];
         }
     }];
}

#pragma mark - QLPreviewController

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller
{
    return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
{
    return [NSURL fileURLWithPath:_filePath];
}

@end
