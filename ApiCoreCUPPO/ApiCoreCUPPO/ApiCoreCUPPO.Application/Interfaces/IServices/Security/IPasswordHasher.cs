namespace ApiCoreCUPPO.Application.Interfaces.IServices.Security
{
    public interface IPasswordHasher
    {
        string Hash(string password);
        bool Verify(string password, string hash);
    }
}
