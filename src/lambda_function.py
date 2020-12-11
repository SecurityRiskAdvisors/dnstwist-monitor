#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Monitor for typosquatting domains using dnstwist and AWS

dnstwist: https://github.com/elceef/dnstwist

AWS Resources:
    - CloudWatch
    - DynamoDB
    - Lambda
    - Systems Manager
"""

# AWS imports
import boto3
import botocore
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key, Attr

# Jira imports
from jira import JIRA

# dnstwist imports
from dnstwist import dnstwist
try:
    import queue
except ImportError:
    import Queue as queue

# Other imports
import datetime as DT
import json
import logging
import os
import sys
import time

# GLOBALS
LOGGER = logging.getLogger()
LOGGER.setLevel(logging.WARN)
DYNAMODB_TABLE_NAME = ""
REGION_NAME = "us-east-1"

def createJiraTicketObject(event, data):
    jira_project = 'DNSTWIST' # DNSTWIST, truncated due to project length limit
    OriginalDomain = event["OriginalDomain"]
    DetectedDomain = data["domain-name"]
    ClientCode = event["ClientCode"]
    issue_object = {
        "project": jira_project, 
        "summary": "dnstwist Discovery: " + str(DetectedDomain) + " similar to " + str(OriginalDomain),
        "description": "Please investigate the following potential typosquatting domain." \
                       "\n\nDetails:" \
                       "\n" + json.dumps(data, indent=4),
        "issuetype": {"name": "Task"},
        "labels": [str(ClientCode)]
    }
    return issue_object

def batchAddJiraTickets(tickets, event):
    # initialize Jira connection information
    ssm_client = boto3.client("ssm", region_name=REGION_NAME)
    include_client_code_in_parameter_name = True
    try:
        if os.environ["genericssm"]:
            if os.environ["genericssm"].lower() == "false":
                include_client_code_in_parameter_name = True
            elif os.environ["genericssm"].lower() == "true":
                include_client_code_in_parameter_name = False
    except:
        pass # keep existing value for include_client_code_in_parameter_name
    if include_client_code_in_parameter_name:
        incl = "_"+event["ClientCode"]
    else:
        incl = ""
    username = ssm_client.get_parameter(Name="/dnstwist_monitor"+incl+"/jira_username", WithDecryption=False)["Parameter"]["Value"]
    password = ssm_client.get_parameter(Name="/dnstwist_monitor"+incl+"/jira_pass", WithDecryption=True)["Parameter"]["Value"]
    api_url = ssm_client.get_parameter(Name="/dnstwist_monitor"+incl+"/jira_url", WithDecryption=False)["Parameter"]["Value"]

    try:
        jira = JIRA(basic_auth=(username, password), options={"server": api_url})
    except Exception as e:
        LOGGER.critical(("Could not connect to JIRA. Error: %s" % (str(e))))
        raise

    issues = jira.create_issues(field_list=tickets)
    LOGGER.info("Batch created %d ticket(s) in Jira" % len(tickets))
    return issues

def diff(event, data):
    domain = event["OriginalDomain"]
    client = event["ClientCode"]

    global DYNAMODB_TABLE_NAME
    DYNAMODB_TABLE_NAME = "dnstwist_monitor_"+client+"_history"
    dynamodb = boto3.resource('dynamodb', region_name=REGION_NAME)
    table = dynamodb.Table(DYNAMODB_TABLE_NAME)

    existingquery = table.scan()

    existingItemsCount = existingquery["Count"]

    existingItems = existingquery["Items"]
    existingDomains = []

    jira_ticket_batch = []

    for i in existingItems:
        existingDomains.append(i["DomainName"])

    if existingItemsCount == 0:
        LOGGER.info("No items in history table")

    for d in data:
        epoch = time.time()
        humantime = DT.datetime.utcfromtimestamp(epoch).isoformat()
        if d["domain-name"] not in existingDomains:
            obj = {
                "DomainName": d["domain-name"],
                "OriginalDomain": domain,
                "Fuzzer": d["fuzzer"],
                "ClientID": client,
                "RawData": str(d),
                "DiscoveredAt": str(humantime)
            }
            table.put_item(Item=obj)
            jira_ticket_batch.append(createJiraTicketObject(event, d))
            LOGGER.info(obj)
    # batch add jira tickets
    try:
        batchAddJiraTickets(jira_ticket_batch, event)
    except Exception as e:
        LOGGER.critical(("Could not connect to JIRA. Error: %s" % (str(e))))

def lambda_handler(event, context):
    # Take log level in from env
    try:
        if os.environ["dnstwistlogginglevel"]:
            if os.environ["dnstwistlogginglevel"] == "WARN":
                LOGGER.setLevel(logging.WARN)
            elif os.environ["dnstwistlogginglevel"] == "INFO":
                LOGGER.setLevel(logging.INFO)
    except:
        pass # keep existing log level of WARN and continue

    domain = event["OriginalDomain"]

    LOGGER.info("Running dnstwist for domain: " + domain)

    url = dnstwist.UrlParser(domain)

    dfuzz = dnstwist.DomainFuzz(domain)
    dfuzz.generate()
    domains = dfuzz.domains
    
    LOGGER.info("Processing %d domain variants " % len(domains))

    jobs = queue.Queue()

    global threads
    threads = []

    for i in range(len(domains)):
        jobs.put(domains[i])

    for i in range(dnstwist.THREAD_COUNT_DEFAULT*20):
        worker = dnstwist.DomainThread(jobs)
        worker.setDaemon(True)

        worker.uri_scheme = url.scheme
        worker.uri_path = url.path
        worker.uri_query = url.query

        worker.domain_orig = url.domain

        worker.start()
        threads.append(worker)
    
    qperc = 0
    while not jobs.empty():
        #LOGGER.info('.')
        qcurr = 100 * (len(domains) - jobs.qsize()) / len(domains)
        if qcurr - 15 >= qperc:
            qperc = qcurr
            LOGGER.info('%u%%' % qperc)
        time.sleep(1)

    for worker in threads:
        worker.stop()
        worker.join()

    hits_total = sum('dns-ns' in d or 'dns-a' in d for d in domains)
    hits_percent = 100 * hits_total / len(domains)
    LOGGER.info(' %d hits (%d%%)\n\n' % (hits_total, hits_percent))

    domains[:] = [d for d in domains if len(d) > 2]
    
    if domains:
        data = dnstwist.generate_json(domains)
        data = json.loads(data)
        try:
            if event["local"]:
                LOGGER.info("Running locally, not using DynamoDB... Printing findings")
                for d in data:
                    LOGGER.info(d)
        except KeyError: # running in AWS
            LOGGER.info("Comparing to DynamoDB history...")
            diff(event, data)


if __name__ == "__main__":
    LOGGER.addHandler(logging.StreamHandler())
    LOGGER.setLevel(logging.WARN)
    event = {
        "ClientCode": "ABC0",
        "OriginalDomain": "google.com",
        "local": True
    }
    context = None # not needed for testing
    lambda_handler(event, context)
