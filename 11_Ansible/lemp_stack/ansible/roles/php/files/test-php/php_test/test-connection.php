<?php
$servername = "localhost"; 
$username = "root"; 
$password = "password"; 

$conn = new mysqli($servername, $username, $password);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error); 
}

$sql = "SELECT VERSION()"; 
$result = $conn->query($sql); 

if ($result->num_rows > 0) {
    
    while($row = $result->fetch_assoc()) {
        print_r($row);
    }
} else {
    echo "0 results";
}
$conn->close(); 
?>