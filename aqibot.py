import itchat, airquality, schedule
import time
from itchat.content import *
from threading import Thread

@itchat.msg_register([TEXT, MAP, CARD, NOTE, SHARING])
def textReply(msg):
    msg.user.send(needProtect())

def needProtect():
    unhealthy = airquality.anyUnhealthyAqi()
    message = '根据上海市未来12小时AQI预测数据，建议您在接下来的12小时内『{}』'.format('戴口罩' if unhealthy else '放轻松')
    return message

@itchat.msg_register(FRIENDS)
def add_friend(msg):
    msg.user.verify()
    msg.user.send('欢迎订阅！发送任意消息查询今后12小时户外是否需要佩戴口罩，每天07:00推送警示信息')

def sendMessageToAllFriends(message):
    for friend in itchat.get_friends():
        friend.send(message)

def sendWarningToAllFriends():
    warning = needProtect()
    sendMessageToAllFriends(warning)

def runScheduler():
    while True:
        schedule.run_pending()
        time.sleep(10)

schedule.every().day.at("07:00").do(sendWarningToAllFriends)
itchat.auto_login()
thread = Thread(target=runScheduler)
thread.start()
itchat.run(True)