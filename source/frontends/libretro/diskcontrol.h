#pragma once

#include "frontends/libretro/buffer.h"

#include "Disk.h"

#include <vector>
#include <string>

namespace ra2
{

    enum class PlaylistStartDisk
    {
        First,
        Previous
    };

    struct DiskInfo
    {
        std::string path;
        std::string label;
        bool writeProtected = IMAGE_FORCE_WRITE_PROTECTED;
        bool createIfNecessary = IMAGE_DONT_CREATE;
        bool isSaveDisk = false;
    };

    class DiskControl
    {
    public:
        DiskControl();

        const std::string &getCurrentDiskFolder() const;
        bool getEjectedState() const;
        bool setEjectedState(bool state);

        size_t getImageIndex() const;
        bool setImageIndex(size_t index);

        size_t getNumImages() const;

        bool replaceImageIndex(size_t index, const std::string &path);
        bool removeImageIndex(size_t index);
        bool addImageIndex();

        // these 2 functions update the images for the Disc Control Interface
        bool insertDisk(const Drive_e drive, const std::string &path);
        bool insertPlaylist(const std::string &path);

        bool getImagePath(unsigned index, char *path, size_t len) const;
        bool getImageLabel(unsigned index, char *label, size_t len) const;

        static void setInitialPath(unsigned index, const char *path);

        void serialise(Buffer<char> &buffer) const;
        void deserialise(Buffer<char const> &buffer);

    private:
        std::vector<DiskInfo> myImages;

        // per-drive state for multi-drive support
        bool myEjected[NUM_DRIVES];
        size_t myIndex[NUM_DRIVES];

        std::string myCurrentDiskFolder;

        Drive_e activeDrive() const;
        bool setEjectedStateForDrive(const Drive_e drive, bool state);
        bool insertFloppyDisk(
            const Drive_e drive, const std::string &path, const bool writeProtected, bool const createIfNecessary);
        bool insertHardDisk(const std::string &path);
        void storeCurrentDiskFolder(const std::string &path);

        // these are here because they are set before we have create a game context
        static unsigned ourInitialIndex;
        static std::string ourInitialPath;
    };

} // namespace ra2
