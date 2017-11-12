import requests
import datetime
from datetime import timezone
from dateutil.parser import parse

def getDifferHour(time1, time2):
    return (time2 - time1).total_seconds() / 3600

def isTimeAppropriate(time1, time2):
    differHour = getDifferHour(time1, time2)
    return -3 <= differHour and differHour <= 15

def utc_to_local(utc_dt):
    return utc_dt.replace(tzinfo=timezone.utc).astimezone(tz=None)

def toLocalTime(datetime):
    return utc_to_local(parse(datetime)).replace(tzinfo=None)

def get_chrome_user_headers():
    return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36(KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36', \
        'Connection': 'keep-alive', \
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8', \
        'Accept-Encoding': 'gzip, deflate, br', \
        'Accept-Language': 'zh-CN,zh;q=0.8'}

cityCodes = {'shanghai': '1437'}

def getAqiServiceUrl(city):
    return 'https://api.waqi.info/api/feed/@%s/obs.cn.json' % cityCodes[city]

def getAqiList(city=None):
    if city is None:
        city = 'shanghai'
    aqiHttpRequest = requests.get(getAqiServiceUrl(city), headers=get_chrome_user_headers())
    qualityJson = aqiHttpRequest.json()
    aqiList = qualityJson['rxs']['obs'][0]['msg']['forecast']['aqi']
    return aqiList

def getAqi(time=None):
    if time is None:
        time = datetime.datetime.now()
    aqiList = getAqiList()
    dailyAqi = [tuple for tuple in aqiList if isTimeAppropriate(time, toLocalTime(tuple['t']))]
    return dailyAqi

def anyUnhealthyAqi(dailyAqi=None, threshold=None):
    if dailyAqi is None:
        dailyAqi = getAqi()
    if threshold is None:
        threshold = 100
    return any(aqi for aqi in map(lambda tuple:tuple['v'], dailyAqi) if (any(value for value in aqi if int(value) > threshold)))