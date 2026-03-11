import requests
from bs4 import BeautifulSoup


def parse_html(url):
    response = requests.get(url)
    soup = BeautifulSoup(response.content, "html.parser")
    return soup


url = "http://example.com"
html = parse_html(url)
print(html.prettify())
