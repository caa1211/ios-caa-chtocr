//
//  OCRResultView.m
//  ios-caa-chtocr
//
//  Created by Carter Chang on 8/31/15.
//  Copyright (c) 2015 Carter Chang. All rights reserved.
//

#import "OCRResultView.h"

@interface OCRResultView () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end


@implementation OCRResultView


- (instancetype)initWithDelegate:(id<OCRResultViewDelegate>)delegate {
    self = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class])
                                          owner:self
                                        options:nil] firstObject];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DefaultCell"];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollEnabled = NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _ocrResults.count;
}

- (void)setOcrResults:(NSMutableArray*)ocrResults{
    _ocrResults = ocrResults;
    [self.tableView reloadData];
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DefaultCell" forIndexPath:indexPath];
    cell.backgroundColor = tableView.backgroundColor;
    cell.textLabel.text = ((NSString *)_ocrResults[indexPath.row]);
    cell.textLabel.font = [UIFont systemFontOfSize:18];
    cell.textLabel.textColor = [UIColor colorWithRed:0.335 green:0.632 blue:0.916 alpha:1.000];
    cell.separatorInset = UIEdgeInsetsZero;
    cell.layoutMargins = UIEdgeInsetsZero;
    cell.preservesSuperviewLayoutMargins = NO;

    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    return OCRResultViewCellHeight;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([self.delegate respondsToSelector:@selector(didSelectOCRResult:)]) {
        [self.delegate didSelectOCRResult:_ocrResults[indexPath.row]];
    }
}



/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
