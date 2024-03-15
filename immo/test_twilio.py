from twilio.rest import Client

def send_sms(content):

    client = Client(account_sid, auth_token)

    for number in ['+15142491501']: #, '+15149380071']:
        message = client.messages.create(
            to=number,
            body=content,
            from_='+13213207252'
        )
    print(message.sid)