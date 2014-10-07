//
//  BMESettingsViewController.m
//  BeMyEyes
//
//  Created by Simon Støvring on 09/03/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

#import "BMESettingsViewController.h"
#import <MRProgress/MRProgress.h>
#import <MessageUI/MessageUI.h>
#import "BMEClient.h"
#import "BMEUser.h"
#import "BMEEmailValidator.h"
#import "BMETaskTableViewCell.h"

@interface BMESettingsViewController () <UITextFieldDelegate, MFMailComposeViewControllerDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UILabel *headlineLabel;
@property (weak, nonatomic) IBOutlet UILabel *firstNameLabel;
@property (weak, nonatomic) IBOutlet UITextField *firstNameTextField;
@property (weak, nonatomic) IBOutlet UILabel *lastNameLabel;
@property (weak, nonatomic) IBOutlet UITextField *lastNameTextField;
@property (weak, nonatomic) IBOutlet UILabel *emailLabel;
@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UILabel *knownLanguagesLabel;
@property (weak, nonatomic) IBOutlet UITextField *knownLanguagesTextField;
@property (weak, nonatomic) IBOutlet UIButton *selectLanguagesButton;
@property (weak, nonatomic) IBOutlet UIButton *feedbackButton;
@property (weak, nonatomic) IBOutlet UITableView *TasksTableView;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;
@property (assign, nonatomic) BOOL shouldSave;
@end

@implementation BMESettingsViewController

#pragma mark -
#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [MKLocalization registerForLocalization:self];
    
    [self populateFields];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self populateFields];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self saveIfSettingChanged];
}

- (void)shouldLocalize {
    self.headlineLabel.text = MKLocalizedFromTable(BME_SETTINGS_HEADLINE, BMESettingsLocalizationTable);
    self.firstNameLabel.text = MKLocalizedFromTable(BME_SETTINGS_FIRST_NAME, BMESettingsLocalizationTable);
    self.lastNameLabel.text = MKLocalizedFromTable(BME_SETTINGS_LAST_NAME, BMESettingsLocalizationTable);
    self.emailLabel.text = MKLocalizedFromTable(BME_SETTINGS_EMAIL, BMESettingsLocalizationTable);
    
    self.knownLanguagesTextField.text = MKLocalizedFromTable(BME_SETTINGS_LANGUAGES, BMESettingsLocalizationTable);
    [self.selectLanguagesButton setTitle:MKLocalizedFromTable(BME_SETTINGS_ADD_LANGUAGES, BMESettingsLocalizationTable) forState:UIControlStateNormal];
    [self.feedbackButton setTitle:MKLocalizedFromTable(BME_SETTINGS_FEEDBACK, BMESettingsLocalizationTable) forState:UIControlStateNormal];
    NSString *logoutString = [NSString stringWithFormat:@"  %@", MKLocalizedFromTable(BME_SETTINGS_LOG_OUT, BMESettingsLocalizationTable)];
    [self.logoutButton setTitle:logoutString forState:UIControlStateNormal];
    
    self.dismissButton.accessibilityLabel = MKLocalizedFromTableWithFormat(BME_SETTINGS_DISMISS_BUTTON_ACCESSIBILITY_LABEL, BMESettingsLocalizationTable);
    
    self.versionLabel.text = MKLocalizedFromTableWithFormat(BME_SETTINGS_VERSION_TITLE, BMESettingsLocalizationTable, [self versionString]);
}

#pragma mark -
#pragma mark Private Methods

- (IBAction)logOutButtonPressed:(id)sender {
    MRProgressOverlayView *progressOverlayView = [MRProgressOverlayView showOverlayAddedTo:self.view.window animated:YES];
    progressOverlayView.mode = MRProgressOverlayViewModeIndeterminate;
    progressOverlayView.titleLabelText = MKLocalizedFromTable(BME_SETTINGS_OVERLAY_LOGGING_OUT_TITLE, BMESettingsLocalizationTable);
    
    [[BMEClient sharedClient] logoutWithCompletion:^(BOOL success, NSError *error) {
        [progressOverlayView hide:YES];
        
        if (!error || [error code] == BMEClientErrorUserTokenNotFound) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BMEDidLogOutNotification object:nil];
            
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            NSLog(@"Could not log out: %@", error);
            
            NSString *title = MKLocalizedFromTable(BME_SETTINGS_ALERT_LOG_OUT_FAILED_TITLE, BMESettingsLocalizationTable);
            NSString *message = MKLocalizedFromTable(BME_SETTINGS_ALERT_LOG_OUT_FAILED_MESSAGE, BMESettingsLocalizationTable);
            NSString *cancelTitle = MKLocalizedFromTable(BME_SETTINGS_ALERT_LOG_OUT_FAILED_CANCEL, BMESettingsLocalizationTable);
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelTitle otherButtonTitles:nil, nil];
            [alertView show];
        }
    }];
}

- (IBAction)settingValueChanged:(id)sender {
    self.shouldSave = YES;
}

- (IBAction)feedbackButtonPressed:(id)sender {
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *initialBody = [NSString stringWithFormat:@"\n\n%@ %@", appName, [self versionString]];
    MFMailComposeViewController *mailComposeController = [MFMailComposeViewController new];
    mailComposeController.mailComposeDelegate = self;
    [mailComposeController setToRecipients:@[ BMEFeedbackRecipientEmail ]];
    [mailComposeController setSubject:BMEFeedbackEmailSubject];
    [mailComposeController setMessageBody:initialBody isHTML:NO];
    [self presentViewController:mailComposeController animated:YES completion:nil];
}

- (void)validateEmail {
    if (![BMEEmailValidator isEmailValid:[self.emailTextField text]]) {
        self.emailTextField.text = [BMEClient sharedClient].currentUser.email;
    }
}

- (void)populateFields {
    BMEUser *user = [BMEClient sharedClient].currentUser;
    self.firstNameTextField.text = user.firstName;
    self.lastNameTextField.text = user.lastName;
    self.emailTextField.text = user.email;
    
    NSArray *knownLanguageCodes = [NSMutableArray arrayWithArray:[BMEClient sharedClient].currentUser.languages];
    NSMutableString *knownLanguages = [NSMutableString new];
    for (NSString *languageCode in knownLanguageCodes) {
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:languageCode];
        NSString *languageString = [[locale displayNameForKey:NSLocaleIdentifier value:languageCode] capitalizedStringWithLocale:[NSLocale currentLocale]];
        if (languageCode == knownLanguageCodes.firstObject) {
            [knownLanguages appendString:languageString];
        } else {
            [knownLanguages appendFormat:@", %@", languageString];
        }
    }
    self.knownLanguagesTextField.text = knownLanguages;
}

- (void)saveIfSettingChanged {
    if (self.shouldSave) {
        [self save];
        self.shouldSave = NO;
    }
}

- (void)save {
    [[BMEClient sharedClient] updateCurrentUserWithFirstName:[self.firstNameTextField text] lastName:[self.lastNameTextField text] email:[self.emailTextField text] completion:^(BOOL success, NSError *error) {
        [self populateFields];
        
        if (!error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BMEDidUpdateProfileNotification object:nil];
        } else {
            NSLog(@"Could not save user information: %@", error);
        }
    }];
}

- (NSString *)versionString {
    NSString *majorVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *minorVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:@"%@ (%@)", majorVersion, minorVersion];
}

#pragma mark -
#pragma mark Text Field Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self validateEmail];
    [self saveIfSettingChanged];
    
    return NO;
}

#pragma mark -
#pragma mark Mail Compose View Controller Delegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BMETaskTableViewCell *cell = (BMETaskTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"TaskTableViewCellID"];
    
    cell.title = @"Hello";
    cell.detail = @"+45 points";
    
    return cell;
}

@end
