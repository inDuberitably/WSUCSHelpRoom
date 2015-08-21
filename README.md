# WSU CS Help Room
The goal of this repo is to build and maintain services for Wright State's Computer Science Help Room. 

#Admin Tools

1. EmailBot - In testing
2. SlackBot - TBD
3. Web App  - TBD

#EmailBot
The email bot manages requests for time off.

First, make sure all the files are in the same directory.
* EmailBot.rb	

* EmailRequestForm.rb

* email_list.txt	

* phrases.txt	

* pop3.txt	

* smtp.txt	

* subjects.txt

To set it up, configure the email service you'll be using following the wiki from https://github.com/mikel/mail/wiki/Sending-email-via-Office365



Setup the **pop3.txt** and **smtp.txt** file with the relevant information from there. I haven't tested whether or not the login part in smtp will break with other services like Office365. It's probably best to leave it there.

In order to email to multiple people you'll need to declare inside the **email_list.txt**

```ruby```
#comma delimited, write entire list on one line
emailname@domain.com, anothercoolemail@someotherdomain.com, howsmytyping@cooldomain.com 
```

**phrases.txt** will display all the key words that award the entire shift

**subjects.txt** will only read emails with the list of these subject headers
Both of phrases and subjects can be modified freely.

To run, simply run from the command line 
```ruby```
ruby EmailBot.rb
````
Once it's all said in done, the script looks like this.

![alt text](http://i.imgur.com/82Qg4Rd.png "First message")

![alt text](http://i.imgur.com/SuPmtk1.png "Someone replying, being rewarded that time")

![alt text](http://i.imgur.com/3tssmb2.png "Someone replying to only part of the time")
