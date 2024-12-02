import os
import requests
import json
import time



endpoint = "https://sample.openai.azure.com"
YOUR_API_KEY = ""


HEADERS = {
    'api-key': YOUR_API_KEY,
    'Content-Type': 'application/json',
}

params = {
    'api-version': '2024-05-01-preview',
}

def get_thread_id(thread_id):
    return thread_id


def create_thread():
    url = endpoint+ '/openai/threads'
    response = requests.post(url, headers=HEADERS, params=params)
    print(response.text, response.url)
    thread_id = response.json()['id']
    print("NEW_THREAD_CREATED", thread_id)
    return thread_id


def add_message_to_thread(thread_id, message):
    json_data = {
        'role': 'user',
        'content': message
    }
    url = endpoint + '/openai/threads/' + thread_id + '/messages'
    response = requests.post(url, headers=HEADERS, json=json_data, params=params)
    message_id = response.json()['id']
    return message_id


def all_messages_in_thread(thread_id):
    url = endpoint + '/openai/threads/' + thread_id + '/messages'
    response = requests.get(url, headers=HEADERS, params=params)
    return response.json()['data']


def run(assistant_id, thread_id):
    print("RUNNING_THREAD thread_id:", thread_id)
    all_messages_in_thread(thread_id)
    json_data = {
        'assistant_id': assistant_id
    }
    url = endpoint + '/openai/threads/' + thread_id + '/runs'
    response = requests.post(url, headers=HEADERS, json=json_data, params=params)
    run_id = response.json()['id']
    return run_id


def check_run_status(run_id, thread_id):
    url = endpoint + '/openai/threads/' + thread_id + '/runs/' + run_id
    response = requests.get(url, headers=HEADERS, params=params)
    run_status = response.json()['status']
    return run_status


def assistant_output(thread_id):
    url = endpoint + '/openai/threads/' + thread_id + '/messages'
    response = requests.get(url,headers=HEADERS, params=params)
    assistant_message = [message for message in response.json()['data'] if message['role'] == 'assistant'][0] or {}
    reply = [reply for reply in assistant_message.get('content', {}) if reply.get('type', '') == 'text'][0] or []
    return reply.get('text', {}).get('value', 'Error in processing')


def process_user_query(user_query):
    print("PROCESS_USER_QUERY", thread_id, user_query)
    add_message_to_thread(thread_id, user_query)
    run_id = run(assistant_id, thread_id)
    wait_until_run_completed(run_id, thread_id)
    return assistant_output(thread_id)


def wait_until_run_completed(run_id, thread_id):
    while check_run_status(run_id, thread_id) != 'completed':
        print("RUN_ID_CHECK_STATUS:", check_run_status(run_id, thread_id))
        time.sleep(1)

