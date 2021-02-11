module dtg.entrycache;

import std;
import dtg.database;

class EntryCache
{
    struct SearchResult
    {
        string[] tags;
        Entry[] entries;
    }

    Entry[] _entries;

    void addEntry(Entry entry)
    {
        _entries ~= entry;
    }

    void addEntries(Entry[] entries)
    {
        _entries ~= entries;
    }
    
    SearchResult search(string[] tags)
    {
        SearchResult searchResult;
        searchResult.entries = _entries.filter!(e => tags.all!(t => e.tags.canFind(t))).array;
        searchResult.tags = searchResult.entries.map!(e => e.tags).array.join().sort.uniq.filter!(t => !tags.canFind(t)).array;
        return searchResult;
    }
}

unittest
{
    auto cache = new EntryCache();
    
    void compareSearchResult(string[] tags, string[] expectedEntries, string[] expectedTags)
    {
        auto searchResult = cache.search(tags);
        assert(searchResult.tags.isPermutation(expectedTags));
        assert(searchResult.entries.map!(e => e.relFilePath).isPermutation(expectedEntries));
    }

    cache.addEntry(Entry("a", "a", "String to float", ["string", "conversion", "float"]));
    cache.addEntry(Entry("b", "b", "String to int", ["string", "conversion", "int"]));
    cache.addEntry(Entry("c", "c", "Float decimal part", ["float", "math"]));
    cache.addEntry(Entry("d", "d", "Cross sum", ["math"]));

    compareSearchResult([], ["a", "b", "c", "d"], ["string", "conversion", "float", "int", "math"]);
    compareSearchResult(["string"], ["a", "b"], ["conversion", "float", "int"]);
    compareSearchResult(["string", "conversion"], ["a", "b"], ["float", "int"]);
    compareSearchResult(["float"], ["a", "c"], ["string", "conversion", "math"]);
}
