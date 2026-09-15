namespace SmartParking.Domain
{
    public class ParkingSpot
    {
        public int Id { get; set; }
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public bool IsAvailable { get; set; }
    }
}
