module dtg.database;

import std;
import dyaml;

class Database
{
    private Folder[] _folders;
    private Entry[] _entries;
    private string _dataFolderPath;
    private string[] _tags;

    @property Entry[] entries()
    {
        return _entries;
    }
    
    @property Folder[] folders()
    {
        return _folders;
    }
    
    @property string[] tags()
    {
        return _tags;
    }

    this(string folderPath)
    {
        _dataFolderPath = folderPath;
        
        string configFile = buildPath(_dataFolderPath, "config.yaml");
        Node configNode = Loader.fromFile(configFile).load();
    
        foreach(string tag; configNode["tags"]) _tags ~= tag;

        foreach (DirEntry e; dirEntries(_dataFolderPath, SpanMode.shallow).array)
        {
            if (e.isDir)
                _folders ~= getFolder(e.name);
        }
    }
    
    private Folder getFolder(string path)
    {
        string relFolderPath = path[_dataFolderPath.length + 1..$].replace("\\", "/");
        string folderTitle = path.baseName;
        string folderConfigFilePath = buildPath(path, "config.yaml");
        if (exists(folderConfigFilePath))
        {
            Node configNode = Loader.fromFile(folderConfigFilePath).load();
            if ("title" in configNode)
            {
                folderTitle = configNode["title"].as!string;
            }
        }

        Folder folder = Folder(path, relFolderPath, folderTitle);
        foreach (DirEntry e; dirEntries(path, "*.md", SpanMode.shallow).array)
        {
            if (e.isDir)
            {
                folder.folders ~= getFolder(e.name);
            }
            else
            {
                string entryTitle =  e.baseName.stripExtension;
                string entryContent = readText(e.name);
                string[] tags;
                if (entryContent.startsWith("---"))
                {
                    auto endPosition = entryContent[3..$].indexOf("---");
                    endPosition = (endPosition == -1) ? endPosition : endPosition + 3;
                    if (endPosition > -1)
                    {
                        string yamlContent = entryContent[3 .. endPosition];
                        Node entryNode = Loader.fromString(yamlContent).load();
                        if ("title" in entryNode)
                        {
                            entryTitle = entryNode["title"].as!string;
                        }
                        if ("tags" in entryNode)
                        {
                            foreach(string tag; entryNode["tags"]) tags ~= tag;
                        }
                    }
                }

                Entry entry = Entry(e.name, e.name[_dataFolderPath.length + 1..$].replace("\\", "/"), entryTitle, tags);
                folder.entries ~= entry;
                _entries ~= entry;
            }
        }
        return folder;
    }
}

struct Folder
{
    string folderPath;
    string relFolderPath;
    string title;
    Folder[] folders;
    Entry[] entries;
}


struct Entry
{
    string filePath;
    string relFilePath;
    string title;
    string[] tags;
}