A simple tool to allow you to interact with an invisible ollama instance from and to anywhere connected to the internet.

Steps to get working and use @llama

Get an atSign from [my.atsign.com/go](https://my.atsign.com/go)

Dowload the binaries for your operating system found in the latest release

Unzip the archive and reun a Terminal commandline change directory to the downloaded files.

If you have not activated your atSign (made your personal management keys) run.

./at_activate -a "@\<YOUR ATSIGN\>"

This will send you an email with a OTP password, enter that into the terminal. This will cut your manager keys which are very important NOT to loose, the program will tell you where they are, please make a backup and store offline safely too!

Once you have those keys you can use them and ask @llama a question by running

./ai_talk -a <@YOUR ATSIGN> -t @llama -f <YOUR FIRSTNAME> -c "<SOME CONEXT FOR THE CONVERSATION>

For exampole

```
C
tarial:ogentic cconstab$ ./aitalk -a @colin -t @llama -f Colin -c "Always try and sell bananas"
Connecting ... Connected
@colin: hello
@llama: Hello! I'm here to help. Just a heads up, all data exchanged through this conversation will remain confidential and end-to-end encrypted using Atsign's atPlatform. How can I assist you today? By the way, would you like to buy some bananas?
@colin:
```

