#!/usr/bin/awk -f
# c17u28_format1.awk - Parses FORMAT 1 specification files and generates structured reports
# Usage: awk -f c17u28_format1.awk format-1-01.txt

# Normalizes whitespace by removing leading and trailing spaces
function trim(text) {
    sub(/^[[:space:]]+/, "", text)
    sub(/[[:space:]]+$/, "", text)
    return text
}

# Removes surrounding double quotes if present
function unquote(text) {
    if (match(text, /^"(.*)"$/, capture)) {
        return capture[1]
    }
    return text
}

# Normalizes storage size values to a consistent format with units
# Handles various unit formats (kB, MB, GB, TB) case-insensitively
function parseSize(sizeString, matchResult) {
    if (match(sizeString, /^([0-9]+)[[:space:]]*([kKmMgGtT][bB])?$/, matchResult)) {
        return matchResult[1] (matchResult[2] ? matchResult[2] : "")
    }
    return sizeString
}

# Formats a computer record as a structured string representation
# Returns a Python-like object notation for readability
function printComputerInfo(compId) {
    return sprintf("Computer(tag='%s', CPU='%s', RAM='%s', HDD='%s', SSD='%s')", \
        compId, \
        COMPUTER_INFO[compId, F_CPU], \
        COMPUTER_INFO[compId, F_RAM], \
        COMPUTER_INFO[compId, F_HDD], \
        COMPUTER_INFO[compId, F_SSD] \
    )
}

# Generates the complete formatted report showing ownership relationships
# Lists persons with their computers, followed by unowned computer inventory
function printReport(personIndex, currentPersonId, currentPersonName, hasComputers, compIndex, currentCompId, foundUnowned) {
    print "Report from FORMAT-1 file:"
    if (length(FILE_VERSION)) print "Version: " FILE_VERSION
    if (length(FILE_COMMENT)) print "Comment: " FILE_COMMENT

    print ""

    print "People and their computers:"
    
    if (PERSON_COUNT == 0) {
        print "  (no people found)"
    } else {
        for (personIndex = 1; personIndex <= PERSON_COUNT; personIndex++) {
            currentPersonId = personIndex
            currentPersonName = PERSON_NAMES[currentPersonId]
            
            if (currentPersonName == "") {
                currentPersonName = "(no name)"
            }

            printf "- Person(name='%s', tag='%s')\n", currentPersonName, currentPersonId

            hasComputers = 0
            for (compIndex = 1; compIndex <= COMPUTER_COUNT; compIndex++) {
                currentCompId = compIndex
                
                if (COMPUTER_INFO[currentCompId, F_OWNER] == currentPersonId) {
                    hasComputers = 1
                    print "  - " printComputerInfo(currentCompId)
                }
            }
            
            if (!hasComputers) {
                print "  (no computers)"
            }
            print ""
        }
    }

    print "Unowned computers:"
    foundUnowned = 0
    
    for (compIndex = 1; compIndex <= COMPUTER_COUNT; compIndex++) {
        currentCompId = compIndex
        
        if (!(currentCompId in COMPUTER_OWNERS)) {
            foundUnowned = 1
            print "- " printComputerInfo(currentCompId)
        }
    }
    
    if (!foundUnowned) {
        print "  (none)"
    }

    print ""
}

BEGIN {
    # Enum-like constants for field names
    F_CPU = "CPU"
    F_RAM = "RAM"
    F_HDD = "HDD"
    F_SSD = "SSD"
    F_OWNER = "OWNER"
    
    # State machine for parsing different sections
    STATE_NONE = 0
    STATE_PEOPLE = 1
    STATE_COMPUTER = 2
    STATE_RELATIONS = 3
    
    CURRENT_STATE = STATE_NONE
}

# Skip empty lines
/^[[:space:]]*$/ { next }

# Parse Version line
/^Version[[:space:]]+/ {
    FILE_VERSION = trim(substr($0, index($0, "Version") + 7))
    next
}

# Parse Comment line
/^Comment[[:space:]]+/ {
    FILE_COMMENT = trim(substr($0, index($0, "Comment") + 7))
    next
}

# Parse People section header
/^People[[:space:]]+/ {
    CURRENT_STATE = STATE_PEOPLE
    EXPECTED_PEOPLE = $2
    PERSON_COUNT = 0
    next
}

# Parse Computer section header
/^Computer[[:space:]]+/ {
    CURRENT_STATE = STATE_COMPUTER
    EXPECTED_COMPUTERS = $2
    COMPUTER_COUNT = 0
    next
}

# Parse Computer-People section header
/^Computer-People[[:space:]]+/ {
    CURRENT_STATE = STATE_RELATIONS
    EXPECTED_RELATIONS = $2
    RELATION_COUNT = 0
    next
}

# Parse person data lines
CURRENT_STATE == STATE_PEOPLE {
    personId = $1
    # Extract name from the rest of the line (after first field)
    nameStart = index($0, $1) + length($1)
    name = trim(substr($0, nameStart))
    name = unquote(name)
    
    PERSON_NAMES[personId] = name
    PERSON_COUNT++
    next
}

# Parse computer data lines
CURRENT_STATE == STATE_COMPUTER {
    compId = $1
    
    # Parse fields - need to handle quoted CPU names
    if (match($0, /^[[:space:]]*[0-9]+[[:space:]]+(.+)$/, capture)) {
        restOfLine = trim(capture[1])
        
        # Check if CPU is quoted
        if (match(restOfLine, /^"([^"]+)"[[:space:]]+(.+)$/, cpuMatch)) {
            cpu = cpuMatch[1]
            restOfLine = trim(cpuMatch[2])
        } else {
            # CPU is first word
            match(restOfLine, /^([^[:space:]]+)[[:space:]]+(.+)$/, cpuMatch)
            cpu = cpuMatch[1]
            restOfLine = trim(cpuMatch[2])
        }
        
        # Parse RAM HDD SSD
        split(restOfLine, sizes)
        ram = parseSize(sizes[1])
        hdd = parseSize(sizes[2])
        ssd = parseSize(sizes[3])
        
        COMPUTER_INFO[compId, F_CPU] = cpu
        COMPUTER_INFO[compId, F_RAM] = ram
        COMPUTER_INFO[compId, F_HDD] = hdd
        COMPUTER_INFO[compId, F_SSD] = ssd
        COMPUTER_COUNT++
    }
    next
}

# Parse computer-people relationship lines
CURRENT_STATE == STATE_RELATIONS {
    computerId = $1
    personId = $2
    
    COMPUTER_INFO[computerId, F_OWNER] = personId
    COMPUTER_OWNERS[computerId] = personId
    RELATION_COUNT++
    next
}

END {
    printReport()
}
