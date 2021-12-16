module dtg.mkdocs;

import std.path, std.file, std.stdio, std.string;
import std.algorithm, std.array, std.range;
import dtg.database, dtg.entrycache;

class MkdocsBuilder
{
    string _outputFolder;
    Database _database;
    EntryCache _entryCache;

    this(string outputFolder, Database database, EntryCache entryCache)
    {
        _outputFolder = outputFolder;
        _database = database;
        _entryCache = entryCache;
    }

    void build()
    {
        if (!exists(buildPath(_outputFolder, "docs")))
            mkdirRecurse(buildPath(_outputFolder, "docs"));

        buildIndexFile(_database.folders);
        buildTopicsIndexFile(_database.folders);
        buildTopicIndexFiles(_database.folders);
        buildEntryFiles(_database.folders);
        buildTagsFiles();

        string topicsMenu = buildTopicsMenu(_database.folders, 4);

        string result = "site_name: D Tips\n" ~
        "site_url: https://andre2007.github.io/d-tips/\n" ~
        "site_author: Andre Pany\n" ~
        "site_description: Tips for D\n" ~
        "copyright: Andre Pany" ~
        "\n" ~
        "theme:\n" ~
        "  name: cinder\n" ~
        "  colorscheme: darcula\n" ~
        "  highlightjs: true\n" ~
        "  hljs_languages:\n" ~
        "    - d\n" ~
        "    - dockerfile\n" ~
        "\n" ~
        "nav:\n" ~
        "  - Home: index.md\n" ~
        "  - By topics:\n" ~
        topicsMenu ~
        "  - By tags: tags.md\n" ~
        "\n" ~
        "markdown_extensions:\n" ~
        "  - codehilite\n" ~
        "  - pymdownx.emoji:\n" ~
        "      emoji_index: !!python/name:materialx.emoji.twemoji\n" ~
        "      emoji_generator: !!python/name:materialx.emoji.to_svg\n";

        result.toFile(buildPath(_outputFolder, "mkdocs.yml"));
    }
    
    void buildIndexFile(Folder[] folders)
    {
        string result = "# Topics\n\n" ~ buildFolderLinkList(folders, false, false);
        result.toFile(buildPath(_outputFolder, "docs", "index.md"));
    }

    void buildTopicsIndexFile(Folder[] folders)
    {
        string result = "# Topics\n\n" ~ buildFolderLinkList(folders, true, false);
        result.toFile(buildPath(_outputFolder, "docs", "topics.md"));
    }

    void buildTagsFiles()
    {
        void buildTagsFile(string[] tags)
        {
            string result = "# Tags\n\n";
            foreach(tag; tags)
            {
                result ~= "- " ~ "["~tag~"](./" ~ tag ~ ")\n";
            }
            result.toFile(buildPath(_outputFolder, "docs", "tags.md"));
        }
        
        string tagsFolderPath = buildPath(_outputFolder, "docs", "tags");
        if (!exists(tagsFolderPath))
                mkdirRecurse(tagsFolderPath);

        string[][] tagsCombinations;
        foreach(entry; _database.entries)
        {
            tagsCombinations ~= getTagsCombinations(entry.tags);
        }
        tagsCombinations = tagsCombinations.sort.array.uniq.array;
        buildTagsFile(tagsCombinations.filter!(tagCombination => tagCombination.length == 1).join);

        foreach(tagCombination; tagsCombinations)
        {
            string filePath = buildPath(_outputFolder, "docs", "tags", tagCombination.join("__") ~ ".md");
            auto sr = _entryCache.search(tagCombination);
            string fileContent = "# Tags: " ~ tagCombination.join(", ") ~ "\n\n";

            foreach(entry; sr.entries)
            {
                fileContent ~= "- [" ~ entry.title ~ "](../../" ~ entry.relFilePath.stripExtension ~ ")\n";
            }

            

            fileContent ~= "\n\nRelated tags: " ~ sr.tags.map!(tag => "["~tag~"](../"~(tagCombination ~ [tag]).sort.join("__")~")").join(" ");

            fileContent.toFile(filePath);
        }
    }

    private string[][] getTagsCombinations(string[] tags)
    {
        string[][] getCombinationsRecursive(string[] tags)
        {
            string[][] result;
            for(int i = 0; i < tags.length; i++)
            {
                result ~= tags[i .. $];
                result ~= (i == 0) ? [tags[0]] : [tags[0]] ~ [tags[i]];
            }
            return (tags.length > 0) ? result ~ getCombinationsRecursive(tags[1 .. $]) : result;
        }
        
        return getCombinationsRecursive(tags).sort.uniq.array;
    }

    void buildEntryFiles(Folder[] folders)
    {
        void buildRecursive(Folder[] folders, int level = 1) {
            foreach(folder; folders)
            {
                foreach(entry; folder.entries)
                {
                    string entryContent = readText(entry.filePath);
                    string parentFolderPath = (level + 1).iota.map!(i => "../").join;
                    entryContent ~= "\n\nTags: " ~ entry.tags.map!(t => "["~t~"](" ~ parentFolderPath ~ "tags/" ~ t ~ ")").join(", ");
                    entryContent.toFile(buildPath(_outputFolder, "docs", entry.relFilePath));

                }
                buildRecursive(folder.folders, level + 1);
            }
        }
        buildRecursive(folders);
    }
    
    void buildTopicIndexFiles(Folder[] folders)
    {           
        string relBaseFolderPath;
        
        string buildRecursive(Folder folder, long level) {
            string result;
            
            foreach(entry; folder.entries)
            {
                result ~= "- [" ~ entry.title ~ "](" ~ entry.relFilePath[relBaseFolderPath.length + 1 .. $] ~ ")\n";
            }
            
            foreach(f; folder.folders)
            {
                result ~= "".rightJustify((level + 1), '#') ~ " [" ~ f.title ~ "](" ~ f.relFolderPath[relBaseFolderPath.length + 1 .. $] ~ "/index.md)\n";
                result ~= buildRecursive(f, level + 1);  
            }
            
            return result;
        }

        foreach(folder; folders)
        {
            relBaseFolderPath = folder.relFolderPath;
            string result = "# " ~ folder.title ~ "\n\n" ~ buildRecursive(folder, 1);
            string indexFilePath = buildPath(_outputFolder, "docs", folder.relFolderPath, "index.md");
            if (!exists(indexFilePath.dirName))
                mkdirRecurse(indexFilePath.dirName);
            result.toFile(buildPath(_outputFolder, "docs", folder.relFolderPath, "index.md"));
            buildTopicIndexFiles(folder.folders);
        }
    }

    string buildFolderLinkList(Folder[] folders, bool includeSubFolders, bool includeEntries)
    {
        string buildRecursive(Folder[] folders, long level) {
            string result;
            foreach(folder; folders)
            {
                result ~= "".rightJustify(level * 4) ~ "- [" ~ folder.title ~ "](" ~ folder.relFolderPath ~ "/index.md)\n";
                if (includeSubFolders)
                    result ~= buildRecursive(folder.folders, level + 1);
                if (includeEntries)
                {
                    foreach(entry; folder.entries)
                    {
                        result ~= "".rightJustify((level + 1) * 4) ~ "- [" ~ entry.title ~ "](" ~ entry.relFilePath ~ ")\n";
                    }
                }
            }
            return result;
        }
        return buildRecursive(folders, 0);
    }
    
    string buildTopicsMenu(Folder[] folders, long indent)
    {
        string buildRecursive(Folder[] folders, long indent) {
            string result;
        
            foreach(folder; folders)
            {
                if (folder.folders == [])
                {
                    result ~= "".rightJustify(indent) ~ "- " ~ folder.title ~ ": " ~ folder.relFolderPath ~ "/index.md\n";
                }
                else
                {
                    result ~= "".rightJustify(indent) ~ "- " ~ folder.title ~ ":\n";
                    result ~= "".rightJustify(indent + 2) ~ "- Overview: " ~ folder.relFolderPath ~ "/index.md\n";
                    result ~= buildRecursive(folder.folders, indent + 2);
                }
            }
            
            return result;
        }
        
        string result = "".rightJustify(indent) ~ "- Overview: topics.md\n";
        result ~= buildRecursive(folders, indent);
        return result;
    }
}
