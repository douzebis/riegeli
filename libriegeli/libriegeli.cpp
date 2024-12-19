#include <iostream>
#include <string>
#include <cstring>
#include "riegeli/bytes/fd_reader.h"
#include "riegeli/records/record_reader.h"

// Global file reader and initialization flag
static riegeli::FdReader<riegeli::OwnedFd>* file_reader = nullptr;
static riegeli::RecordReader<riegeli::FdReader<riegeli::OwnedFd> *> * reader = nullptr;


// Instanciate the RecordReader
// FIXME: this interface is really hacky
extern "C" int riegeli_init(const char* file_path) {

    // Open the Riegeli file using FdReader
    if (file_reader) {
        std::cerr << "RecordReader can be instanciated once only!" << std::endl;
        return -1;
    }
    file_reader = new riegeli::FdReader(file_path);
    if (!file_reader->ok()) {
        std::cerr << "Error opening file: " << file_reader->status() << std::endl;
        return -2;
    }
    // Create a RecordReader to read records from the file
    reader = new riegeli::RecordReader(std::move(file_reader));
    if (!reader->ok()) {
        std::cerr << "Error creating reader: " << reader->status() << std::endl;
        return -3;
    }
    return 0;
}

extern "C" char* riegeli_read_record(size_t* len) {

    if (!file_reader) {
        //riegeli_RecordReader("data.riegeli");
        std::cerr << "RecordReader is not instanciated!" << std::endl;
        return 0;
    }

    // Read the next record
    std::string record;
    if (reader->ReadRecord(record)) {
        *len = record.size();
        char* cString = (char*)malloc(*len);
        if (cString) {
            memcpy(cString, record.data(), record.size());
        }
        return cString;

    } else {
        return 0;
    }
}

// Free allocated memory
extern "C" void riegeli_free(char* str) {
    free(str);
}
