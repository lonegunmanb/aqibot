import requests
import time

def get_chrome_user_headers():
    return {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
        (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36', \
        'Connection': 'keep-alive', \
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8', \
        'Accept-Encoding': 'gzip, deflate, br', \
        'Accept-Language': 'zh-CN,zh;q=0.8'}

cityCodes = {'shanghai': '1437'}

def getAqiServiceUrl(city):
    return 'https://api.waqi.info/api/feed/@%s/obs.cn.json' % cityCodes[city]

def getAqiList(city='shanghai'):
    aqiHttpRequest = requests.get(getAqiServiceUrl(city), headers=get_chrome_user_headers())
    qualityJson = aqiHttpRequest.json()
    aqiList = qualityJson['rxs']['obs'][0]['msg']['forecast']['aqi']
    return aqiList


def getAqi(datetime=time.localtime()):
    todayString = time.strftime("%Y-%m-%d", datetime)
    aqiList = getAqiList()
    dailyAqi = [tuple for tuple in aqiList if tuple['t'].startswith(todayString)]
    return dailyAqi

def anyUnhealthyAqi(dailyAqi=getAqi(), threshold=100):
    return any(aqi for aqi in map(lambda tuple:tuple['v'], dailyAqi) if (any(value for value in aqi if int(value) > threshold)))