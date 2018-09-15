import json
import urllib.request
import sys
from collections import OrderedDict
import jsonpickle
from elasticsearch import Elasticsearch, helpers

#print("Python Version")
#print(sys.version)

################################################################################################################
class BibleBook(object):
      def __init__(self, Book, Chapter, VerseNumber, VerseText):
          self.book = Book
          self.chapter = Chapter
          self.versenumber = VerseNumber
          self.versetext = VerseText
################################################################################################################

if __name__ == "__main__":
   Bible = [] 
   # Contains a json list of all 66 books of the bible
   bibleBooksUrl = "https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/Books.json"

   # Retrieve the json list of all 66 books of the bible and insert them into a list
   with urllib.request.urlopen(bibleBooksUrl) as url:
        bibleBooks = json.loads(url.read().decode(), object_pairs_hook=OrderedDict)

   baseUrl = "https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/"
   for a, b in enumerate(bibleBooks):
       bibleBookJsonFileUrl = "{}{}.json".format(baseUrl, b.replace(" ", ""))
       
       # Get the bible book
       #print("Processing Url: {}".format(bibleBookJsonFileUrl))
       with urllib.request.urlopen(bibleBookJsonFileUrl) as fileUrl:
            result = jsonpickle.loads(fileUrl.read().decode())
            book = result["book"]
            numberOfChapters = len([len(x) for x in result["chapters"]])
            #print("{}({})".format(book, numberOfChapters))
            for a in range(numberOfChapters):
                chapter = result["chapters"][a]["chapter"]
                numberOfVerses = len([len(z) for z in result["chapters"][a]["verses"]])
                #print("Chapter {} - Number Of Verses: {}".format(chapter, numberOfVerses))
                for b in range(numberOfVerses):
                   jsonDump  = json.dumps(result["chapters"][a]["verses"][b], separators=(',',':'))
                   for key, value in result["chapters"][a]["verses"][b].items():
                       verseNumber = key
                       verseText = value
                       bibleBook = BibleBook(book, chapter, verseNumber, verseText)
                       Bible.append(bibleBook)
   
   # Create mapping object
   es = Elasticsearch() 
   
   # delete index if exists
   if es.indices.exists("bible-kjv"):
      es.indices.delete(index="bible-kjv")
   # index settings
   settings = {"settings": {"number_of_shards": 1,  "number_of_replicas": 0 },
    "mappings": {
        "bible-kjv": {
            "properties": {
                "book": { "type": "text", "fields": { "keyword": { "type": "keyword" } } },
                "chapter": {"type": "long"},
                "verseNumber":{"type": "long" },
                "verseText": {"type": "text", "fielddata": "true" } 
            }
        }
     }
   }
   # create index
   result = es.indices.create(index="bible-kjv", ignore=400, body=settings)
   # insert data into elasticsearch
   idCounter = 0
   for i in range(len(Bible)):
       book        = Bible[i].book
       chapter     = Bible[i].chapter
       versenumber = Bible[i].versenumber
       versetext   = Bible[i].versetext
       biblejson = { "book": book, "chapter": chapter, "verseNumber": versenumber, "verseText": versetext }  
       result = es.index(index="bible-kjv", doc_type="bible-kjv",id=idCounter, body=biblejson)
       print(result)
       print("Inserted Book: {} -  Chapter: {} - Verse Number:{}".format(book, chapter,versenumber))
       idCounter = idCounter + 1
