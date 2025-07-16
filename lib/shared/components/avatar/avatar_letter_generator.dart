String generateName(fullName) {
  var firstLetter = '';
  var firstLetterAfterSpace = '';
  var name = fullName;
  var indexOfSpace = name?.indexOf(" ");
  firstLetter = name?[0].trim().toUpperCase() ?? '';
  firstLetterAfterSpace = name?[indexOfSpace! + 1].trim().toUpperCase() ?? '';
  return '$firstLetter $firstLetterAfterSpace';
}
