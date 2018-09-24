fitbitSettings = {
    'ClientID': '',
    'ClientSecret':'',
    'CallbackUrl': '',
    'OAuthAuthorizeUri':'',
    'OAuthAccessRefreshTokenRequestUri': '',
    'LoggingApp':'FitbitDataImporter',
    'LoggingDirectory':'',
    'LogFileName': 'FitbitDataImport.log'
}
fitbitDataConfigSettings = []
HEART_RATE_SETTINGS = {
            'PrefixIndexName': 'fitbit-daily-activites-heart-rate-',
            'IndexType':'heartrate',
            'FieldName':'heartrate',
            'ResourceName': 'activities/heart',
            'DataIndex': 'activities-heart-intraday',
            'DetailLevel': '1sec',
            'DataType':'Heart Rate'
}

STEP_SETTINGS = {
            'PrefixIndexName': 'fitbit-daily-activites-steps-',
            'IndexType':'steps',
            'FieldName':'steps',
            'ResourceName': 'activities/steps',
            'DataIndex': 'activities-steps-intraday',
            'DetailLevel': '1min',
            'DataType':'Steps'
}
SLEEP_SETTINGS = {
             'PrefixIndexName': 'fitbit-daily-activites-sleep-',
             'IndexType':'sleep',
             'FieldName':'',
             'ResourceName': 'activities/steps',
             'DataIndex': 'sleep',
             'DetailLevel': '1min',
             'DataType':'Sleep'
}
fitbitDataConfigSettings.append(HEART_RATE_SETTINGS)
fitbitDataConfigSettings.append(STEP_SETTINGS)
fitbitDataConfigSettings.append(SLEEP_SETTINGS)