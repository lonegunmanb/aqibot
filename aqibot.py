import itchat, airquality
from itchat.content import *

@itchat.msg_register([TEXT, MAP, CARD, NOTE, SHARING])
def textReply(msg):
    msg.user.send('echo %s' % needProtect())

def needProtect():
    unhealthy = airquality.anyUnhealthyAqi()
    return '戴口罩' if unhealthy else '放轻松'

@itchat.msg_register(FRIENDS)
def add_friend(msg):
    msg.user.verify()
    msg.user.send('Nice to meet you!')

itchat.auto_login()
# for friend in itchat.get_friends():
#     friend.send(needProtect())
itchat.run(True)