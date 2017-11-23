from flask import Flask
import json
import sys
import requests

app = Flask(__name__)


mdUrl = "http://169.254.169.254/metadata/instance?api-version=2017-04-02"
header = {'Metadata':'True'}

@app.route("/")
def hello():
    print("client request connecting...")
    r=requests.get(url=mdUrl, headers=header)
    print("retrun from 169.254.169.254 endpoint ...")
    return r.text   
  
if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)