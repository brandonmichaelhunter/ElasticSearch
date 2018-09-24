##########################################################################################
# FitbitDataImporter.py                                                                  #
# Author: Brandon M. Hunter                                                              #
# Date: 06.03.2018                                                                       #
# Description: This script will collect a user's activity data from their Fitbit account #
# and push the data to ElasticSearch.                                                    #
##########################################################################################
import fitbit
from FitbitSettingsDev import fitbitSettings,fitbitDataConfigSettings
#from fitbitSettings import fitbitDataConfigSettings
from pythonfitbit import gather_keys_oauth2 as OAuth2
from datetime import datetime, date, time, timedelta
import time
from elasticsearch import Elasticsearch, helpers
import logging
import logging.handlers
import objgraph

# global variables
CLIENT_ID = fitbitSettings['ClientID']
CLIENT_SECRET = fitbitSettings['ClientSecret']
CALLBACK_URL = fitbitSettings['CallbackUrl']
OAUTH_2_0_AUTHORIZATION_URI = fitbitSettings['OAuthAuthorizeUri']
OAUTH_2_0_ACCESS_REFRESH_TOKEN_REQUEST_URI = fitbitSettings['OAuthAccessRefreshTokenRequestUri']
START_TIME = ''
END_TIME = ''
DETAIL_LEVEL = ''
PREFIX_INDEX_NAME = ''
COUNTER = 0
ES_OPERATION_RESULT =''
SVR = ''
ESCLIENT = None

OAUTH2CLIENT = None

# Initialize logging capabilities 
def InitLogging():
    global LOGGER
    # Initalizing logging configuration.
    LOGGER = logging.getLogger(fitbitSettings['LoggingApp'])
    LOGGER.setLevel(logging.DEBUG)

    # create file handler which logs even debug messages
    fh = logging.FileHandler("{}{}".format(fitbitSettings['LoggingDirectory'],fitbitSettings['LogFileName']))
    fh.setLevel(logging.DEBUG)

    # create formatter and add it to the handlers
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    LOGGER.addHandler(fh)

    # Ingest Fitbit data

# Ingest data from fitbit into ElasticSearch
def IngestFitbitData(Config, DoFullDayImport, NumberOfDays, esClient,authClient):
    

    # Configuration variable
    PREFIX_INDEX_NAME = Config['PrefixIndexName']
    INDEX_TYPE        = Config['IndexType']
    FIELD_NAME        = Config['FieldName']
    RESOURCE_NAME     = Config['ResourceName']
    DATA_INDEX        = Config['DataIndex']
    DETAIL_LEVEL      = Config['DetailLevel']
    DATA_TYPE         = Config['DataType']
    COUNTER           = 0

    LOGGER.info("Retrieving Fitbit {} Data".format(DATA_TYPE))
    # Check to see if we need to get a full day worth of data or not
    if(DoFullDayImport == True):
       lookupDate = str((datetime.now() - timedelta(days=NumberOfDays)).strftime("%Y-%m-%d"))
       START_TIME = '00:00'
       END_TIME   = '23:59'
    else:
       lookupDate      = str(datetime.now().strftime("%Y-%m-%d"))
       start_date_time = datetime.now() - timedelta(minutes=5)
       end_date_time   = datetime.now()
       START_TIME      = start_date_time.strftime('%H:%M')
       END_TIME        = end_date_time.strftime('%H:%M')

    # If the index does not exists, then create a new index.
    INDEX_NAME = "{}{}".format(PREFIX_INDEX_NAME,lookupDate)
    if(esClient.indices.exists(INDEX_NAME) == False):
       LOGGER.info("Creating {} index".format(INDEX_NAME))
       # Configure a different mapping for Sleep data type
       if DATA_TYPE == 'Sleep':
          indexSettings = {"settings": {"index": {"number_of_shards": 1,"number_of_replicas": 0}},"mappings": {"{}".format(INDEX_TYPE): {"properties": {"@timestamp": {"type": "date", "format": "YYYY-MM-dd HH:mm:ss.SSS"},"Duration":{"type": "float"},"Efficiency":{"type": "float"},"IsMainSleep":{"type": "keyword"},"MinutesAfterWakeup":{"type": "float"},"MinutesAsleep":{"type": "float"},"MinutesAwake":{"type": "float"},"MinutesToFallAsleep":{"type": "float"},"SleepStartTime":{"type": "date", "format": "YYYY-MM-dd HH:mm:ss.SSS"},"SleepEndTime":{"type": "date", "format": "YYYY-MM-dd HH:mm:ss.SSS"},"TimeInBed":{"type": "float"},"RestlessCount":{"type": "float"},"RestlessDuration":{"type": "float"},"AwakeCount":{"type": "float"},"AwakeDuration":{"type": "float"},"AwakeningsCount":{"type": "float"},"dateOfSleep":{"type": "keyword"},"SleepState":{"type": "keyword"}}}}}
       else:
           indexSettings = {"settings": {"index": {"number_of_shards": 1,"number_of_replicas": 0}},"mappings": {"{}".format(INDEX_TYPE): {"properties": {"@timestamp": {"type": "date", "format": "YYYY-MM-dd HH:mm:ss.SSS"},"{}".format(FIELD_NAME): {"type": "float"}}}}}

       esClient.indices.create(index = INDEX_NAME, body=indexSettings )
       LOGGER.info("{} index has been created".format(INDEX_NAME))

    # - Get fitbit data
    if DATA_TYPE == 'Sleep':
       lookupDate = (datetime.now() - timedelta(days=NumberOfDays))

       fitbitDataList = authClient.get_sleep(lookupDate)[DATA_INDEX]
       if len(fitbitDataList) > 0:
          awakeCount          = fitbitDataList[0]['awakeCount']
          awakeDuration       = fitbitDataList[0]['awakeDuration']
          awakeningsCount     = fitbitDataList[0]['awakeningsCount']
          dateOfSleep         = fitbitDataList[0]['dateOfSleep']
          duration            = fitbitDataList[0]['duration']
          efficency           = fitbitDataList[0]['efficiency']
          isMainSleep         = fitbitDataList[0]['isMainSleep']
          sleepStartTime      = fitbitDataList[0]['startTime'].replace('T',' ')
          sleepEndTime        = fitbitDataList[0]['endTime'].replace('T',' ')
          minutesAfterWakeup  = fitbitDataList[0]['minutesAfterWakeup']
          minutesAsleep       = fitbitDataList[0]['minutesAsleep']
          minutesAwake        = fitbitDataList[0]['minutesAwake']
          minutesToFallAsleep = fitbitDataList[0]['minutesToFallAsleep']
          restlessCount       = fitbitDataList[0]['restlessCount']
          restlessDuration    = fitbitDataList[0]['restlessDuration']
          timeInBed           = fitbitDataList[0]['timeInBed']

          # - Extract and load fitbit heart rate data into ElasticSearch
          TOTAL_IMPORTED_ROWS = len(fitbitDataList[0]['minuteData'])
          LOGGER.info("Importing {} rows into ElasticSearch".format(TOTAL_IMPORTED_ROWS))
          dataItem  = ''
          dataItems = []
          for data in fitbitDataList[0]['minuteData']:
              # - Convert data into the following format: 'YYYY-MM-DD HH:MM:SS.SSS
              hourString = int(data['dateTime'].split(':')[0])
              sleepStartTimeHour = int(sleepStartTime.split(' ')[1].split(':')[0])
              sleepEndTimeHour = int(sleepEndTime.split(' ')[1].split(':')[0])
              yesterday  = str((datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d"))
              today = str((datetime.now() - timedelta(days=0)).strftime("%Y-%m-%d"))
              yesterdayDTS = "{} {}.000".format(yesterday, data['dateTime'])
              todayDTS = "{} {}.000".format(today, data['dateTime'])

              if hourString <= sleepStartTimeHour and  hourString > sleepEndTimeHour:
                 datetimestamp = yesterdayDTS
              else:
                 datetimestamp = todayDTS

              if data['value'] == '1':
                 sleepState = 'Asleep'
              elif data['value'] == '2':
                   sleepState = 'Awake'
              elif data['value'] == '3':
                   sleepState = 'Very Awake'
              else:
                   sleepState = 'N/A'

              dataItem ={"@timestamp": datetimestamp,"Duration":duration,"Efficiency":efficency,"IsMainSleep":isMainSleep,"MinutesAfterWakeup":minutesAfterWakeup,"MinutesAsleep":minutesAsleep,"MinutesAwake":minutesAwake,"MinutesToFallAsleep":minutesToFallAsleep,"SleepStartTime":sleepStartTime,"SleepEndTime":sleepEndTime,"TimeInBed":timeInBed,"RestlessCount":restlessCount,"RestlessDuration":restlessDuration,"AwakeCount":awakeCount,"AwakeDuration":awakeDuration,"AwakeningsCount":awakeningsCount,"dateOfSleep":dateOfSleep,"SleepState":sleepState}
              ES_OPERATION_RESULT = esClient.index(index=INDEX_NAME, doc_type=INDEX_TYPE, id=COUNTER, body=dataItem)
              COUNTER = COUNTER + 1
          LOGGER.info("Fitbit data imported into ElasticSearch")
       else:
           LOGGER.info("No Fitbit data to import")
    else:
        if len(DETAIL_LEVEL) != 0:
           fitbitDataList = authClient.intraday_time_series(RESOURCE_NAME, base_date=lookupDate, detail_level=DETAIL_LEVEL,  start_time=START_TIME, end_time=END_TIME)
        else:
           fitbitDataList = authClient.intraday_time_series(RESOURCE_NAME, base_date=lookupDate, detail_level=DETAIL_LEVEL,  start_time=START_TIME, end_time=END_TIME)
        
        # - Extract and load fitbit heart rate data into ElasticSearch
        TOTAL_IMPORTED_ROWS = len(fitbitDataList[DATA_INDEX]['dataset'])
        if TOTAL_IMPORTED_ROWS > 0:
            LOGGER.info("Importing {} rows into ElasticSearch".format(TOTAL_IMPORTED_ROWS))
            dataItem  = ''
            dataItems = []
            for data in fitbitDataList[DATA_INDEX]['dataset']:
                # - Convert data into the following format: 'YYYY-MM-DD HH:MM:SS.SSS
                datetimestamp = "{} {}.000".format(lookupDate, data['time'])
                dataItem = {'@timestamp': datetimestamp,'{}'.format(FIELD_NAME): "{}.0".format(data['value']) }
                ES_OPERATION_RESULT = esClient.index(index=INDEX_NAME, doc_type=INDEX_TYPE, id=COUNTER, body=dataItem)
                COUNTER = COUNTER + 1
            LOGGER.info("Fitbit data imported into ElasticSearch")
        else:
            LOGGER.info("No Fitbit data to import")

def main():
    try:
        
        # Connect to fitbit
        SVR = OAuth2.OAuth2Server(CLIENT_ID, CLIENT_SECRET)
        SVR.browser_authorize()
        ACCESS_TOKEN = str(SVR.fitbit.client.session.token['access_token'])
        REFRESH_TOKEN = str(SVR.fitbit.client.session.token['refresh_token'])
        OAUTH2CLIENT = fitbit.Fitbit(CLIENT_ID, CLIENT_SECRET, oauth2=True, access_token=ACCESS_TOKEN, refresh_token=REFRESH_TOKEN)

        # Connect to elasticsearch
        ESCLIENT = Elasticsearch()
        numOfDays = 1
        for fitbitDataConfigSetting in fitbitDataConfigSettings:
            IngestFitbitData(fitbitDataConfigSetting,True, numOfDays, ESCLIENT,OAUTH2CLIENT)
        


    except Exception as e:
           LOGGER.error("Exception Type: {}".format(type(e)))
           LOGGER.error("Error: {}".format(e))

if __name__ == "__main__":
   
   LOGGER.info(objgraph.show_growth(limit=3))
   InitLogging()
   LOGGER.info(objgraph.show_growth())

   LOGGER.info(objgraph.show_growth(limit=3))
   main()
   LOGGER.info(objgraph.show_growth())
   
   # objgraph.show_most_common_types()
